class UserSerializer < ActiveModel::Serializer
  embed :ids, include: true
  attributes :id,
             :name,
             :email,
             :utc_offset,
             :subscribed_to_personal_activity,
             :subscribed_to_daily_digest,
             :subscribed_to_participant_activity,
             :confirmed_at,
             :joined_first_group_at
end
