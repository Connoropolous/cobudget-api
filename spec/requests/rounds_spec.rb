require 'rails_helper'

describe "Rounds" do
  describe "POST /rounds" do
    let(:round_params) { {
      round: {
        group_id: group.id,
        name: "November Surplus",
      }
    }.to_json }

    context 'admin' do
      before { make_user_group_admin }
      it "creates a round" do
        post "/rounds", round_params, request_headers
        round = Round.first

        expect(response.status).to eq created
        expect(round.name).to eq "November Surplus"
      end
    end

    context 'member' do
      before { make_user_group_member }
      it "cannot create a round" do
        post "/rounds", round_params, request_headers
        round = Round.first

        expect(response.status).to eq forbidden
        expect(round).to eq nil
      end
    end
  end

  describe "PUT /rounds/:round_id" do
    let(:round) { FactoryGirl.create(:pending_round, name: 'Goody', group: group) }
    let(:evil_group) { FactoryGirl.create(:group) }
    let(:round_params) { {
      round: {
        name: 'Sky Round',
        group_id: evil_group.id # this should be ignored
      }
    }.to_json }

    context 'admin' do
      before { make_user_group_admin }

      it "updates a round" do
        put "/rounds/#{round.id}", round_params, request_headers
        round.reload
        expect(response.status).to eq 204
        expect(round.name).to eq 'Sky Round'
        expect(round.group_id).not_to eq evil_group.id # don't let admin change group
      end
    end

    context 'member' do
      before { make_user_group_member }
      it "cannot update round" do
        put "/rounds/#{round.id}", round_params, request_headers
        round.reload
        expect(response.status).to eq 403
        expect(round.name).not_to eq 'Sky Round'
      end
    end
  end

  describe "DELETE /rounds/:round_id" do
    context 'admin' do
      before { make_user_group_admin }
      it "deletes a round (and associated dependencies)" do
        round
        bucket
        contribution
        allocation
        fixed_cost
        delete "/rounds/#{round.id}", {}, request_headers
        expect(response.status).to eq updated
        expect { round.reload }.to raise_error # deleted
        expect { bucket.reload }.to raise_error # deleted
        expect { allocation.reload }.to raise_error # deleted
        expect { contribution.reload }.to raise_error # deleted
        expect { fixed_cost.reload }.to raise_error # deleted
      end
    end

    context 'member' do
      before { make_user_group_member }

      it "cannot delete a round" do
        round
        delete "/rounds/#{round.id}", {}, request_headers
        expect(response.status).to eq forbidden
        expect { round.reload }.not_to raise_error # not deleted
      end
    end
  end
end
