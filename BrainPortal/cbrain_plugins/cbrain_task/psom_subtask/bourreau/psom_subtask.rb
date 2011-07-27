
#
# CBRAIN Project
#
# ClusterTask Model PsomSubtask
#
# Original author:
#
# $Id$
#

# A subclass of ClusterTask to run PsomSubtask.
class CbrainTask::PsomSubtask < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  include RestartableTask
  include RecoverableTask

  # See CbrainTask.txt
  def setup #:nodoc:
    params         = self.params || {}
    job_id         = params[:psom_job_id]
    job_name       = params[:psom_job_name]
    job_script     = params[:psom_job_script]
    #job_script = job_script.strip # TODO remove it's a PATCH
    job_subdir     = params[:psom_job_run_subdir]
    desc_dir       = params[:psom_pipe_desc_subdir]
    script_relpath = "#{desc_dir}/#{job_script}"
    cb_error "Cannot find the subdirectory '#{job_subdir}' we need for this job?" unless
      File.directory?(job_subdir)
    cb_error "Cannot find the PSOM script file '#{script_relpath}' we are expected to run?" unless
      File.exist?(script_relpath)
    true
  end

  # See CbrainTask.txt
  def cluster_commands #:nodoc:
    params         = self.params || {}
    job_id         = params[:psom_job_id]
    job_name       = params[:psom_job_name]
    job_script     = params[:psom_job_script]
    #job_script = job_script.strip # TODO remove it's a PATCH
    job_subdir     = params[:psom_job_run_subdir]
    desc_dir       = params[:psom_pipe_desc_subdir]
    script_relpath = "#{desc_dir}/#{job_script}"
    task_workdir   = self.full_cluster_workdir
    # Note that 'psom_octave_wrapper.sh' is supplied in vendor/cbrain/bin on the Bourreau side
    [
      "echo 'PSOM Job ID:    ' #{job_id}",
      "echo 'PSOM Job Name:  ' #{job_name}",
      "echo 'PSOM Job Script:' #{job_script}",
      "echo 'PSOM Job Subdir:' #{job_subdir}",
      "cd '#{job_subdir}'",
      "SECONDS=0",
      "psom_octave_wrapper.sh $PSOM_ROOT/psom_run_job.sh '#{task_workdir}/#{script_relpath}'",
      "echo Completed in $SECONDS seconds."
    ]
  end
  
  # See CbrainTask.txt
  def save_results #:nodoc:
    params       = self.params || {}
    stdoutfile   = self.stdout_cluster_filename
    if ! File.exist?(stdoutfile)
      self.addlog("Cannot find output of psom_run_job ?!?")
      return false
    end
    stdout = File.read(stdoutfile) rescue ""
    unless stdout.index("***Success***")
      self.addlog("It seems psom_run_job did not complete successfully.")
      return false
    end
    # No results to save; it's handled by whatever subclass
    # of CbrainTask::PsomPipelineLauncher created this task.
    true
  end

end

