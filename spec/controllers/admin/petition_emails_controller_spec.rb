require 'rails_helper'

RSpec.describe Admin::PetitionEmailsController, type: :controller, admin: true do

  let!(:petition) { FactoryGirl.create(:open_petition) }

  describe 'not logged in' do
    describe 'GET /new' do
      it 'redirects to the login page' do
        get :new, petition_id: petition.id
        expect(response).to redirect_to('https://moderate.petition.parliament.uk/admin/login')
      end
    end

    describe 'POST /' do
      it 'redirects to the login page' do
        patch :create, petition_id: petition.id
        expect(response).to redirect_to('https://moderate.petition.parliament.uk/admin/login')
      end
    end
  end

  context 'logged in as moderator user but need to reset password' do
    let(:user) { FactoryGirl.create(:moderator_user, force_password_reset: true) }
    before { login_as(user) }

    describe 'GET /new' do
      it 'redirects to edit profile page' do
        get :new, petition_id: petition.id
        expect(response).to redirect_to("https://moderate.petition.parliament.uk/admin/profile/#{user.id}/edit")
      end
    end

    describe 'POST /' do
      it 'redirects to edit profile page' do
        patch :create, petition_id: petition.id
        expect(response).to redirect_to("https://moderate.petition.parliament.uk/admin/profile/#{user.id}/edit")
      end
    end
  end

  describe "logged in as moderator user" do
    let(:user) { FactoryGirl.create(:moderator_user) }
    before { login_as(user) }

    describe 'GET /new' do
      describe 'for an open petition' do
        it 'fetches the requested petition' do
          get :new, petition_id: petition.id
          expect(assigns(:petition)).to eq petition
        end

        it 'responds successfully and renders the petitions/show template' do
          get :new, petition_id: petition.id
          expect(response).to be_success
          expect(response).to render_template('petitions/show')
        end
      end

      shared_examples_for 'trying to view the email petitioners form of a petition in the wrong state' do
        it 'raises a 404 error' do
          expect {
            get :new, petition_id: petition.id
          }.to raise_error ActiveRecord::RecordNotFound
        end
      end

      describe 'for a pending petition' do
        before { petition.update_column(:state, Petition::PENDING_STATE) }
        it_behaves_like 'trying to view the email petitioners form of a petition in the wrong state'
      end

      describe 'for a validated petition' do
        before { petition.update_column(:state, Petition::VALIDATED_STATE) }
        it_behaves_like 'trying to view the email petitioners form of a petition in the wrong state'
      end

      describe 'for a sponsored petition' do
        before { petition.update_column(:state, Petition::SPONSORED_STATE) }
        it_behaves_like 'trying to view the email petitioners form of a petition in the wrong state'
      end
    end

    describe 'POST /' do
      let(:petition_email_attributes) do
        {
          subject: "Petition email subject",
          body: "Petition email body"
        }
      end

      def do_post(overrides = {})
        params = { petition_id: petition.id, petition_email: petition_email_attributes }
        post :create, params.merge(overrides)
      end

      describe 'for an open petition' do
        it 'fetches the requested petition' do
          do_post
          expect(assigns(:petition)).to eq petition
        end

        describe 'with valid params' do
          it 'redirects to the petition show page' do
            do_post
            expect(response).to redirect_to "https://moderate.petition.parliament.uk/admin/petitions/#{petition.id}"
          end

          it 'tells the moderator that their email will be sent overnight' do
            do_post
            expect(flash[:notice]).to eq 'Email will be sent overnight'
          end

          it 'stores the supplied email details in the db' do
            do_post
            petition.reload
            email = petition.emails.last
            expect(email).to be_present
            expect(email.subject).to eq "Petition email subject"
            expect(email.body).to eq "Petition email body"
            expect(email.sent_by).to eq user.pretty_name
          end

          context "emails out the petition email" do
            include ActiveJob::TestHelper

            before do
              3.times do |i|
                attributes = {
                  name: "Laura #{i}",
                  email: "laura_#{i}@example.com",
                  notify_by_email: true,
                  petition: petition
                }
                s = FactoryGirl.create(:pending_signature, attributes)
                s.validate!
              end
              2.times do |i|
                attributes = {
                  name: "Sarah #{i}",
                  email: "sarah_#{i}@example.com",
                  notify_by_email: false,
                  petition: petition
                }

                s = FactoryGirl.create(:pending_signature, attributes)
                s.validate!
              end
              2.times do |i|
                attributes = {
                  name: "Brian #{i}",
                  email: "brian_#{i}@example.com",
                  notify_by_email: true,
                  petition: petition
                }
                FactoryGirl.create(:pending_signature, attributes)
              end
              petition.reload
            end

            it "queues a job to process the emails" do
              assert_enqueued_jobs 1 do
                do_post
              end
            end

            it "stamps the 'petition_email' email sent receipt on each signature when the job runs" do
              perform_enqueued_jobs do
                do_post
                petition.reload
                petition_timestamp = petition.get_email_requested_at_for('petition_email')
                expect(petition_timestamp).not_to be_nil
                petition.signatures.validated.notify_by_email.each do |signature|
                  expect(signature.get_email_sent_at_for('petition_email')).to eq(petition_timestamp)
                end
              end
            end

            it "should email out to the validated signees who have opted in when the delayed job runs" do
              ActionMailer::Base.deliveries.clear
              perform_enqueued_jobs do
                do_post
                expect(ActionMailer::Base.deliveries.length).to eq 5
                expect(ActionMailer::Base.deliveries.map(&:to)).to eq([
                  [petition.creator_signature.email],
                  ['laura_0@example.com'],
                  ['laura_1@example.com'],
                  ['laura_2@example.com'],
                  ['petitionscommittee@parliament.uk']
                ])
              end
            end
          end
        end

        describe 'with invalid params' do
          before { petition_email_attributes.delete(:subject) }

          it 're-renders the petitions/show template' do
            do_post
            expect(response).to be_success
            expect(response).to render_template('petitions/show')
          end

          it 'leaves the in-memory instance with errors' do
            do_post
            expect(assigns(:email)).to be_present
            expect(assigns(:email).errors).not_to be_empty
          end

          it 'does not stores the email details in the db' do
            do_post
            petition.reload
            expect(petition.emails).to be_empty
          end
        end
      end

      shared_examples_for 'trying to email supporters of a petition in the wrong state' do
        it 'raises a 404 error' do
          expect {
            do_post
          }.to raise_error ActiveRecord::RecordNotFound
        end

        it 'does not stores the supplied email details in the db' do
          suppress(ActiveRecord::RecordNotFound) { do_post }
          petition.reload
          expect(petition.emails).to be_empty
        end
      end

      describe 'for a pending petition' do
        before { petition.update_column(:state, Petition::PENDING_STATE) }
        it_behaves_like 'trying to email supporters of a petition in the wrong state'
      end

      describe 'for a validated petition' do
        before { petition.update_column(:state, Petition::VALIDATED_STATE) }
        it_behaves_like 'trying to email supporters of a petition in the wrong state'
      end

      describe 'for a sponsored petition' do
        before { petition.update_column(:state, Petition::SPONSORED_STATE) }
        it_behaves_like 'trying to email supporters of a petition in the wrong state'
      end
    end
  end
end
