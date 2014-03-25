require 'playhouse/role'
require 'cobudget/roles/budget_participant'
require 'cobudget/roles/entry_collection'

module Cobudget
  module TransferSource
    include Playhouse::Role

    actor_dependency :budget
    actor_dependency :balance
    actor_dependency :id

    def can_decrease_money?(amount)
      amount_money = amount
      unless amount.is_a?(Money)
        amount_money = Money.new(amount*100.to_f)
      end

      balance_money = balance
      unless balance.is_a?(Money)
        balance_money = Money.new(balance)
      end

      balance_money - amount_money >= 0
      #balance - amount >= 0
    end

    def decrease_money!(amount, transaction, identifier)
      Entry.create!(amount: -amount, transaction: transaction, account: self, identifier: identifier)
    end

    private

    def accounts_in_same_budget?(transaction)
      self.budget == transaction.destination_account.budget
    end
  end
end
