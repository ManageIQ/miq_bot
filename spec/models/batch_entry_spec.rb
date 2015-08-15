require 'spec_helper'

describe BatchEntry do
  include_examples "state predicates", :succeeded?,
                   nil         => false,
                   "started"   => false,
                   "failed"    => false,
                   "succeeded" => true

  include_examples "state predicates", :failed?,
                   nil         => false,
                   "started"   => false,
                   "failed"    => true,
                   "succeeded" => false

  include_examples "state predicates", :complete?,
                   nil         => false,
                   "started"   => false,
                   "failed"    => true,
                   "succeeded" => true
end
