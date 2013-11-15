require 'cobudget/entities/budget'
require 'cobudget/entities/bucket'

module Cobudget
  class SeedLoader
    def self.load_seed
      budget = Cobudget::Budget.create(name: 'Budget')
      Cobudget::Bucket.create(budget: budget, name: 'First', description: 'description')
    end
  end
end
