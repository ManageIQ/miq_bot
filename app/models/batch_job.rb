class BatchJob < ActiveRecord::Base
  has_many :entries, :class_name => "BatchEntry", :foreign_key => :batch_job_id

  def expired?
    expires_at && Time.now > expires_at
  end

  def complete?
    expired? || entries.all?(&:complete?)
  end
end
