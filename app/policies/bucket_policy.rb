class BucketPolicy < ApplicationPolicy
  def create?
    (
      user.is_admin_for?(record.round.group) and
      record.round.mode != "closed"
    ) or (
      record.round.group.members.include?(user) and
      (record.user_id == user.id) and
      record.round.members_can_propose_buckets and
      record.round.mode == "proposal"
    )
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end
