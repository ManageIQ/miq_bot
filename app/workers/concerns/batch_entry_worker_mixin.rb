module BatchEntryWorkerMixin
  attr_reader :batch_entry

  def find_batch_entry(batch_entry_id)
    @batch_entry = BatchEntry.where(:id => batch_entry_id).first

    if @batch_entry.nil?
      logger.warn("BatchEntry #{batch_entry_id} no longer exists.  Skipping.")
      return false
    end

    true
  end

  def batch_job
    batch_entry.job
  end

  def complete_batch_entry(updates = {})
    update_batch_entry(updates)
    check_job_complete
  end

  def skip_batch_entry
    complete_batch_entry(:state => "skipped")
  end

  private

  def update_batch_entry(updates)
    updates = updates.reverse_merge(:state => "succeeded")
    batch_entry.update_attributes!(updates)
  end

  def check_job_complete
    batch_entry.check_job_complete
  end
end
