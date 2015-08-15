class BatchJob < ActiveRecord::Base
  has_many :entries, :class_name => "BatchEntry", :foreign_key => :batch_job_id

  serialize :on_complete_args, Array

  validates :state, :inclusion => {:in => %w(finalizing), :allow_nil => true}

  def on_complete_class
    super.try(:constantize)
  end

  def on_complete_class=(klass)
    super(klass.to_s)
  end

  def finalizing?
    state == "finalizing"
  end

  def expired?
    expires_at && Time.now > expires_at
  end

  def complete?
    expired? || entries.all?(&:complete?)
  end
end
