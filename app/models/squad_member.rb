class SquadMember < ApplicationRecord
  belongs_to :squad
  belongs_to :user
end
