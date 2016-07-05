class BatchEntry < ActiveRecord::Base
  serialize :result
  belongs_to :job, :class_name => "BatchJob", :foreign_key => :batch_job_id

  validates :state, :inclusion => {:in => %w(started failed succeeded), :allow_nil => true}

  def succeeded?
    state == "succeeded"
  end

  def failed?
    state == "failed"
  end

  def complete?
    failed? || succeeded?
  end

  def check_job_complete
    job.check_complete if job && complete?
  end
end
