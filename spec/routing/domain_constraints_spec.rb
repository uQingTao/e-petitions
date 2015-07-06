require 'rails_helper'

RSpec.describe "domain constraints", type: :routes do
  context "when on the public domain" do
    context "and making a request for a public path" do
      it "is routable" do
        expect(get("/petitions")).to route_to("petitions#index")
      end
    end

    context "and making a request for an admin path" do
      it "is not routeable" do
        expect(get("/admin/login")).not_to be_routable
      end
    end
  end

  context "when on the moderate subdomain", admin: true do
    context "and making a request for a public path" do
      it "is not routeable" do
        expect(get("/petitions")).not_to be_routable
      end
    end

    context "and making a request for an admin path" do
      it "is routable" do
        expect(get("/admin/login")).to route_to("admin/user_sessions#new")
      end
    end
  end
end