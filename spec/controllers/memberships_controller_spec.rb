require 'rails_helper'

describe MembershipsController, :type => :controller do
  describe "#index" do
    context "user member of group" do
      before do
        make_user_group_member
        request.headers.merge!(user.create_new_auth_token)
        create_list(:membership, 5, group: group)
        create_list(:membership, 2, group: group, archived_at: DateTime.now.utc - 5.days)
      end

      context "specified format is json" do
        before do
          get :index, {group_id: group.id, format: :json}
        end

        it "returns http status success" do
          expect(response).to have_http_status(:success)
        end

        it "returns all active memberships for the group" do
          expect(parsed(response)["memberships"].length).to eq(6)
        end
      end

      context "specified format is csv" do
        before do
          get :index, {group_id: group.id, format: :csv}
        end

        it "returns http status 'success'" do
          expect(response).to have_http_status(:success)
        end

        it "returns a csv file of active memberships" do
          expect(response.header["Content-Type"]).to include("text/csv")
          expect(response.header["Content-Disposition"]).to include("attachment; filename=")
          expect(CSV.parse(response.body).length).to eq(6)
        end
      end
    end

    context "user not member of group" do
      it "returns http status forbidden" do
        request.headers.merge!(user.create_new_auth_token)
        get :index, group_id: group.id
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "user not logged in" do
      it "returns http status unauthorized" do
        get :index, group_id: group.id
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "#create" do
    let(:user) { create(:user) }
    let(:group) { create(:group) }
    let(:valid_email) { Faker::Internet.email }

    context "user signed in" do
      before { request.headers.merge!(user.create_new_auth_token) }

      context "user is admin of group" do
        let!(:membership) { create(:membership, member: user, group: group, is_admin: true) }

        context "specified email address belongs to existing user" do
          let!(:existing_user) { create(:user, email: valid_email) }

          before do
            post :create, {group_id: group.id, email: valid_email}
            @new_membership = Membership.find_by(member: existing_user, group: group)
          end

          it "returns http status 'success'" do
            expect(response).to have_http_status(:success)
          end

          it "creates membership" do
            expect(@new_membership).to be_truthy
          end

          it "returns new membership as json" do
            expect(parsed(response)["memberships"][0]["id"]).to eq(@new_membership.id)
          end
        end

        context "specified email address does not belong to existing user" do
          before do
            post :create, {group_id: group.id, email: valid_email}
            @new_user = User.find_by_email(valid_email)
            @new_membership = Membership.find_by(group: group, member: @new_user)
          end

          it "returns http status 'success'" do
            expect(response).to have_http_status(:success)
          end

          it "creates user with confirmation_token" do
            expect(@new_user).to be_truthy
            expect(@new_user.confirmation_token).to be_truthy
          end

          it "creates membership" do
            expect(@new_membership).to be_truthy
          end

          it "returns new membership as json" do
            expect(parsed(response)["memberships"][0]["id"]).to eq(@new_membership.id)
          end
        end

        context "invalid email address" do
          before { post :create, {group_id: group.id, email: "ehehehehuhuh"} }

          it "returns http status 'bad_request'" do
            expect(response).to have_http_status(:bad_request)
          end
        end

        context "membership already exists" do
          let!(:existing_membership) { create(:membership, group: group, is_admin: true) }

          it "returns http status conflict" do
            post :create, {group_id: group.id, email: existing_membership.member.email}
            expect(response).to have_http_status(:conflict)
          end
        end
      end

      context "user not admin of group" do
        before { post :create, {group_id: group.id, email: valid_email} }

        it "returns http status 'forbidden'" do
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context "user not signed in" do
      before { post :create, {group_id: group.id, email: valid_email} }

      it "returns http status 'unauthorized'" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "#show" do
    context "user member of group" do
      before do
        make_user_group_member
        request.headers.merge!(user.create_new_auth_token)
        @membership = create(:membership, group: group)
        get :show, id: @membership.id
      end

      it "returns http status success" do
        expect(response).to have_http_status(:success)
      end

      it "returns specified membership as json" do
        expect(parsed(response)["memberships"][0]["id"]).to eq(@membership.id)
      end
    end

    context "user not member of group" do
      before do
        make_user_group_member
        request.headers.merge!(user.create_new_auth_token)
        @membership = create(:membership)
        get :show, id: @membership.id
      end

      it "returns http status forbidden" do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "user not logged in" do
      it "returns http status unauthorized" do
        membership = make_user_group_member
        get :show, id: membership.id
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "#invite" do
    before do
      @membership_to_invite = create(:membership, group: group)
      @user_to_invite = @membership_to_invite.member
    end

    after do
      ActionMailer::Base.deliveries.clear
    end

    context "current_user signed in" do
      before do
        request.headers.merge!(user.create_new_auth_token)
      end

      context "current_user is admin of user's group" do
        before do
          create(:membership, member: user, group: group, is_admin: true)
          post :invite, {id: @membership_to_invite.id}
          @user_to_invite.reload
        end

        it "returns http status 'success'" do
          expect(response).to have_http_status(:success)
        end

        it "creates a new confirmaton token for the user and resets confirmed_at to nil" do
          expect(@user_to_invite.confirmation_token).to be_truthy
          expect(@user_to_invite.confirmed_at).to be_nil
        end

        it "resends invite email to specified user" do
          sent_emails = ActionMailer::Base.deliveries
          expect(sent_emails.length).to eq(1)
          expect(sent_emails.first.to).to eq([@user_to_invite.email])
        end

        it "returns the user as json" do
          expect(parsed(response)["users"][0]["email"]).to eq(@user_to_invite.email)
        end
      end

      context "current_user not admin of user's group" do
        before do
          post :invite, {id: @membership_to_invite.id}
          @user_to_invite.reload
        end

        it "returns http status forbidden" do
          expect(response).to have_http_status(:forbidden)
        end

        it "does not create a new confirmation token for the user" do
          expect(@user_to_invite.confirmation_token).to be_nil
        end

        it "does not send invite email to specified user" do
          expect(ActionMailer::Base.deliveries.length).to eq(0)
        end
      end
    end

    context "current_user signed in" do
      before do
        post :invite, {id: @membership_to_invite.id}
      end

      it "returns http status 'unauthorized'" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "#my_memberships" do
    context "user logged in" do
      before do
        create_list(:membership, 3, member: user)
        create_list(:membership, 8)
        create_list(:membership, 1, member: user, archived_at: DateTime.now.utc - 5.days)
        request.headers.merge!(user.create_new_auth_token)
        get :my_memberships
      end

      it "returns http status success" do
        expect(response).to have_http_status(:success)
      end

      it "returns all users active memberships" do
        expect(parsed(response)["memberships"].length).to eq(3)
      end
    end

    context "user not logged in" do
      it "returns http status unauthorized" do
        get :my_memberships
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "#archive" do
    before do
      @membership = make_user_group_member
      request.headers.merge!(user.create_new_auth_token)
    end

    context "group admin" do
      before do
        group.add_admin(user)
        post :archive, {id: @membership.id}
        @membership.reload
      end

      it "returns http status ok" do
        expect(response).to have_http_status(:ok)
      end

      it "sets user's archived_at to current time" do
        expect(@membership.archived_at).to be_truthy
      end
    end

    context "not group admin" do
      it "returns http status forbidden" do
        post :archive, {id: @membership.id}
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "#upload_review" do
    let(:valid_csv) { fixture_file_upload('bulk-invite-members-csvs/test-csv.csv', 'text/csv') }
    let(:csv_with_fucked_up_email_addresses) { fixture_file_upload('bulk-invite-members-csvs/test-csv-fucked-up-email-addresses.csv', 'text/csv') }
    let(:csv_with_too_many_columns) { fixture_file_upload('bulk-invite-members-csvs/test-csv-too-many-columns.csv', 'text/csv') }
    let(:totally_fucked_csv) { fixture_file_upload('bulk-invite-members-csvs/totally-fucked-csv.csv', 'text/csv') }
    let(:empty_csv) { fixture_file_upload('bulk-invite-members-csvs/empty-csv.csv', 'text/csv') }

    context "user is group admin" do
      before do
        @membership = make_user_group_admin
        request.headers.merge!(user.create_new_auth_token)
      end

      context "valid csv" do
        before do
          @group = @membership.group
          @person0 = create(:user, email: "person0@example.com", name: "Person0")
          create(:membership, member: @person0, group: @group)
          post :upload_review, {group_id: @membership.group_id, csv: valid_csv}
        end

        it "returns http status 'ok'" do
          expect(response).to have_http_status(:ok)
        end

        it "returns review data as json" do
          expect(parsed(response)).to eq({
            "data" => [
              {"id" => @person0.id, "email" => "person0@example.com", "name" => "Person0", "new_member" => false},
              {"id" => "",          "email" => "person1@example.com", "name" => ""       , "new_member" => true },
              {"id" => "",          "email" => "person2@example.com", "name" => ""       , "new_member" => true }
            ]
          })
        end
      end

      context "csv has fucked up email addresses" do
        it "returns http status 'unprocessable'" do
          post :upload_review, {group_id: @membership.group_id, csv: csv_with_fucked_up_email_addresses}
          expect(response).to have_http_status(422)
        end
      end

      context "csv has more than one column" do
        it "returns http status 'unprocessable'" do
          post :upload_review, {group_id: @membership.group_id, csv: csv_with_too_many_columns}
          expect(response).to have_http_status(422)
        end
      end

      context "csv is empty" do
        it "returns http status 'unprocessable'" do
          post :upload_review, {group_id: @membership.group_id, csv: empty_csv}
          expect(response).to have_http_status(422)
        end
      end
    end

    context "user is not group admin" do
      before do
        membership = make_user_group_member
        request.headers.merge!(user.create_new_auth_token)
        post :upload_review, {group_id: membership.group_id, csv: valid_csv}
      end

      it "returns http status 'forbidden'" do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "user not logged in" do
      before do
        membership = make_user_group_member
        post :upload_review, {group_id: membership.group_id, csv: valid_csv}
      end

      it "returns http status 'unauthorized'" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

end
