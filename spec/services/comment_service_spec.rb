require "rails_helper"

describe "CommentService" do
  describe "#send_new_comment_emails(comment: )" do
    before do
      @membership = make_user_group_member
      @bucket = create(:bucket, group: group, user: user)
      @bucket_author = user
      @comment = create(:comment, bucket: @bucket)
      @comment_author = @comment.user
    end

    after do 
      ActionMailer::Base.deliveries.clear
    end

    it "sends 'notify_user_of_new_comment_email' to all bucket participants subscribed to participant activity, except commenter" do
      # temporarily stub out emails sent to author for this set of specs
      mail_double = double(:mail)
      allow(UserMailer).to receive(:notify_author_of_new_comment_email).and_return(mail_double)
      allow(mail_double).to receive(:deliver_later).and_return(nil)

      # create bucket funder subscribed to participant activity
      @subscribed_funder = create_bucket_participant(bucket: @bucket, subscribed: true, type: :funder)

      # create bucket commenter subscribed to participant activity
      @subscribed_commenter = create_bucket_participant(bucket: @bucket, subscribed: true, type: :commenter)

      # create bucket funder not subscribed to participant activity
      @unsubscribed_funder = create_bucket_participant(bucket: @bucket, subscribed: false, type: :funder)

      # create bucket commenter not subscribed to participant activity
      @unsubscribed_commenter = create_bucket_participant(bucket: @bucket, subscribed: false, type: :commenter)

      # create non participant
      @subscribed_non_participant = create(:user, subscribed_to_participant_activity: true)
      create(:membership, group: group, member: @subscribed_non_participant)

      # create an archived participant
      @archived_participant = create_bucket_participant(bucket: @bucket, subscribed: true)
      Membership.find_by(group: @bucket.group, member: @archived_participant).update(archived_at: DateTime.now.utc - 5.days)

      CommentService.send_new_comment_emails(comment: @comment)
      @email_recipients = ActionMailer::Base.deliveries.map { |e| e.to.first }

      expect(@email_recipients).to include(@subscribed_funder.email)
      expect(@email_recipients).to include(@subscribed_commenter.email)

      expect(@email_recipients).not_to include(@comment_author.email)
      expect(@email_recipients).not_to include(@unsubscribed_funder.email)
      expect(@email_recipients).not_to include(@unsubscribed_commenter.email)
      expect(@email_recipients).not_to include(@subscribed_non_participant.email)
      expect(@email_recipients).not_to include(@archived_participant.email)
    end

    context "bucket author subscribed to personal activity" do
      it "bucket author receives notification email" do
        CommentService.send_new_comment_emails(comment: @comment)
        email_recipients = ActionMailer::Base.deliveries.map { |e| e.to.first }
        expect(email_recipients).to include(@bucket_author.email)
      end
    end

    context "bucket author is subcribed to personal activity, but is also commenter" do
      it "bucket author does not receive notification email" do
        @comment.update(user: @bucket_author)
        CommentService.send_new_comment_emails(comment: @comment)
        email_recipients = ActionMailer::Base.deliveries.map { |e| e.to.first }
        expect(email_recipients).not_to include(@bucket_author.email)        
      end
    end

    context "bucket author not subscribed to personal activity" do
      it "bucket author does not receive notification email" do
        @bucket_author.update(subscribed_to_personal_activity: false)
        CommentService.send_new_comment_emails(comment: @comment)
        email_recipients = ActionMailer::Base.deliveries.map { |e| e.to.first }
        expect(email_recipients).not_to include(@bucket_author.email)
      end
    end

    context "bucket author no longer member of group" do
      it "bucket author does not receive notification email" do
        @membership.update(archived_at: DateTime.now.utc - 5.days)
        CommentService.send_new_comment_emails(comment: @comment)
        email_recipients = ActionMailer::Base.deliveries.map { |e| e.to.first }
        expect(email_recipients).not_to include(@bucket_author.email)
      end      
    end
  end
end
