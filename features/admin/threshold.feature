Feature: Threshold list
  In order to see and action petitions that require a response
  As a moderator or sysadmin user
  I want to see a list of petitions that have exceeded the signature threshold count

  Background:
    Given I am logged in as a moderator
    And the date is the "21 April 2011 12:00"
    And the threshold for a parliamentary debate is "5"
    And an open petition "p1" exists with action: "Petition 1", closed_at: "1 January 2012"
    And the petition "Petition 1" has 25 validated signatures
    And an open petition "p2" exists with action: "Petition 2", closed_at: "20 August 2011"
    And the petition "Petition 2" has 4 validated signatures
    And an open petition "p3" exists with action: "Petition 3", closed_at: "20 September 2011"
    And the petition "Petition 3" has 5 validated signatures
    And a closed petition "p4" exists with action: "Petition 4", closed_at: "20 April 2011"
    And the petition "Petition 4" has 10 validated signatures
    And an open petition "p5" exists with action: "Petition 5"
    And a closed petition "p6" exists with action: "Petition 6", closed_at: "21 April 2011"

  Scenario: A moderator user sees all petitions above the threshold signature count
    When I go to the admin threshold page
    Then I should see the following admin index table:
      | Action     | Count | Closing date |
      | Petition 3 | 5     | 20-09-2011   |
      | Petition 4 | 10    | 20-04-2011   |
      | Petition 1 | 25    | 01-01-2012   |
    And I should be connected to the server via an ssl connection
    And the markup should be valid

  Scenario: Threshold petitions are paginated
    Given I am logged in as a sysadmin
    And 20 petitions exist with a signature count of 6
    When I go to the admin threshold page
    And I follow "Next"
    Then I should see 3 rows in the admin index table
    And I follow "Previous"
    And I should see 20 rows in the admin index table

  Scenario: A moderator user can view the details of a petition and form fields
    When I go to the admin threshold page
    And I follow "Petition 1"
    Then I should see "01-01-2012"
    When I follow "Government response"
    Then I should see a "Summary quote" textarea field
    And I should see a "Response in full" textarea field

  Scenario: A moderator user updates the government response to a petition
    Given the time is "3 Dec 2010 01:00"
    When I go to the admin threshold page
    And I follow "Petition 1"
    And I follow "Government response"
    And I fill in "Summary quote" with "Ready yourselves"
    And I fill in "Response in full" with "Parliament here it comes. This is a long text."
    And I press "Email 25 signatures"
    Then I should be on the admin government response page for "Petition 1"
    And I should see "Email will be sent overnight"
    And the petition with action: "Petition 1" should have requested a government response email after "2010-12-03 01:00:00"
    And the response summary to "Petition 1" should be publicly viewable on the petition page
    And the response to "Petition 1" should be publicly viewable on the petition page
    And the petition signatories of "Petition 1" should receive a response notification email

  Scenario: A moderator user tries to update the government response to a petition without entering anything
    Given the time is "3 Dec 2010 01:00"
    When I go to the admin threshold page
    And I follow "Petition 1"
    And I follow "Government response"
    And I press "Email 25 signatures"
    Then I should be on the admin government response page for "Petition 1"
    But I should not see "Email will be sent overnight"
    And the petition with action: "Petition 1" should not have requested a government response email
    And the petition signatories of "Petition 1" should not receive a response notification email
