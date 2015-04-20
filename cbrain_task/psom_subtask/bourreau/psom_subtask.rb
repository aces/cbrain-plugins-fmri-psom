
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# A subclass of ClusterTask to run PsomSubtask.
class CbrainTask::PsomSubtask < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    params         = self.params || {}

    job_script     = params[:psom_job_script]
    job_subdir     = params[:psom_job_run_subdir]
    desc_dir       = params[:psom_pipe_desc_subdir]
    script_relpath = "#{desc_dir}/#{job_script}"
    # job_script   = job_script.strip # TODO remove it's a PATCH
    # job_id         = params[:psom_job_id]
    # job_name       = params[:psom_job_name]
    cb_error "Cannot find the subdirectory '#{job_subdir}' we need for this job?" unless
      File.directory?(job_subdir)
    cb_error "Cannot find the PSOM script file '#{script_relpath}' we are expected to run?" unless
      File.exist?(script_relpath)
    true
  end

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

  def save_results #:nodoc:
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

