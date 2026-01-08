require "../ralph/test_helper"

module Ralph
  module FlexiblePKTests
    # Test models using String primary key
    class Organization < Model
      table "flex_pk_organizations"

      column id : String, primary: true
      column name : String

      has_many Team
    end

    class Team < Model
      table "flex_pk_teams"

      column id : Int64, primary: true
      column name : String

      belongs_to Organization
      has_many Member
    end

    class Member < Model
      table "flex_pk_members"

      column id : Int64, primary: true
      column name : String
      column team_id : Int64
    end
  end

  describe "Flexible Primary Key Types" do
    before_all do
      RalphTestHelper.setup_test_database

      # Create tables for flexible PK tests
      # Organization uses String primary key - use raw SQL for SQLite
      Ralph.database.execute(<<-SQL)
        CREATE TABLE IF NOT EXISTS flex_pk_organizations (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT
        )
      SQL

      # Team has Int64 PK but references Organization's String PK
      TestSchema.create_table("flex_pk_teams") do |t|
        t.primary_key
        t.string("name")
        t.string("organization_id", size: 36)
      end

      # Member has Int64 PK and references Team's Int64 PK
      TestSchema.create_table("flex_pk_members") do |t|
        t.primary_key
        t.string("name")
        t.bigint("team_id")
      end
    end

    after_all do
      RalphTestHelper.cleanup_test_database
    end

    before_each do
      Ralph.database.execute("DELETE FROM flex_pk_members")
      Ralph.database.execute("DELETE FROM flex_pk_teams")
      Ralph.database.execute("DELETE FROM flex_pk_organizations")
    end

    describe "PrimaryKeyType alias" do
      it "creates correct PrimaryKeyType for String primary key" do
        FlexiblePKTests::Organization::PrimaryKeyType.should eq(String)
      end

      it "creates correct PrimaryKeyType for Int64 primary key" do
        FlexiblePKTests::Team::PrimaryKeyType.should eq(Int64)
      end

      it "reports correct primary_key_type string" do
        FlexiblePKTests::Organization.primary_key_type.should eq("String")
        FlexiblePKTests::Team.primary_key_type.should eq("Int64")
      end
    end

    describe "belongs_to with String FK" do
      it "uses the correct foreign key type for String-keyed parent" do
        # Create an organization with a string ID
        org_id = "org-#{Random.rand(10000)}"
        Ralph.database.execute(
          "INSERT INTO flex_pk_organizations (id, name) VALUES (?, ?)",
          args: [org_id, "Acme Corp"]
        )

        # Create a team referencing this organization
        Ralph.database.execute(
          "INSERT INTO flex_pk_teams (name, organization_id) VALUES (?, ?)",
          args: ["Engineering", org_id]
        )

        team = FlexiblePKTests::Team.first
        team.should_not be_nil

        if team
          # The organization_id should be the string we set
          team.organization_id.should eq(org_id)

          # Loading the association should work
          org = team.organization
          org.should_not be_nil
          org.not_nil!.name.should eq("Acme Corp")
        end
      end

      it "can set belongs_to association with String PK parent" do
        # Create an organization
        org_id = "org-#{Random.rand(10000)}"
        Ralph.database.execute(
          "INSERT INTO flex_pk_organizations (id, name) VALUES (?, ?)",
          args: [org_id, "Test Org"]
        )

        org = FlexiblePKTests::Organization.first.not_nil!

        # Create a team and associate it
        Ralph.database.execute(
          "INSERT INTO flex_pk_teams (name, organization_id) VALUES (?, ?)",
          args: ["Sales", ""]
        )

        team = FlexiblePKTests::Team.first.not_nil!
        team.organization = org
        team.save

        # Reload and verify
        reloaded_team = FlexiblePKTests::Team.find(team.id.not_nil!)
        reloaded_team.should_not be_nil
        reloaded_team.not_nil!.organization_id.should eq(org_id)
      end
    end

    describe "has_many with String PK" do
      it "loads has_many associations for String-keyed parent" do
        # Create an organization with string ID
        org_id = "org-#{Random.rand(10000)}"
        Ralph.database.execute(
          "INSERT INTO flex_pk_organizations (id, name) VALUES (?, ?)",
          args: [org_id, "Multi-Team Org"]
        )

        # Create multiple teams
        Ralph.database.execute(
          "INSERT INTO flex_pk_teams (name, organization_id) VALUES (?, ?)",
          args: ["Team Alpha", org_id]
        )
        Ralph.database.execute(
          "INSERT INTO flex_pk_teams (name, organization_id) VALUES (?, ?)",
          args: ["Team Beta", org_id]
        )

        org = FlexiblePKTests::Organization.first.not_nil!
        teams = org.teams

        teams.size.should eq(2)
        teams.map(&.name).should contain("Team Alpha")
        teams.map(&.name).should contain("Team Beta")
      end
    end

    describe "eager loading with String PK" do
      it "preloads has_many associations for String-keyed parent" do
        # Create organizations with string IDs
        org1_id = "org-#{Random.rand(10000)}"
        org2_id = "org-#{Random.rand(10000)}"
        Ralph.database.execute(
          "INSERT INTO flex_pk_organizations (id, name) VALUES (?, ?)",
          args: [org1_id, "Org One"]
        )
        Ralph.database.execute(
          "INSERT INTO flex_pk_organizations (id, name) VALUES (?, ?)",
          args: [org2_id, "Org Two"]
        )

        # Create teams for each org
        Ralph.database.execute(
          "INSERT INTO flex_pk_teams (name, organization_id) VALUES (?, ?)",
          args: ["Team 1A", org1_id]
        )
        Ralph.database.execute(
          "INSERT INTO flex_pk_teams (name, organization_id) VALUES (?, ?)",
          args: ["Team 1B", org1_id]
        )
        Ralph.database.execute(
          "INSERT INTO flex_pk_teams (name, organization_id) VALUES (?, ?)",
          args: ["Team 2A", org2_id]
        )

        # Use preload to eager load teams
        orgs = FlexiblePKTests::Organization.all
        FlexiblePKTests::Organization.preload(orgs, :teams)

        orgs.size.should eq(2)

        org_one = orgs.find { |o| o.name == "Org One" }.not_nil!
        org_one._has_preloaded?("teams").should be_true
        org_one.teams.size.should eq(2)

        org_two = orgs.find { |o| o.name == "Org Two" }.not_nil!
        org_two._has_preloaded?("teams").should be_true
        org_two.teams.size.should eq(1)
      end
    end
  end
end
