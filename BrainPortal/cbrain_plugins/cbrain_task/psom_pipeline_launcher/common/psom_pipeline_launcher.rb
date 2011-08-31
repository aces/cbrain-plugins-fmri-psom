
#
# CBRAIN Project
#
# ClusterTask Model PsomPipelineLauncher
#
# $Id$
#

#
class CbrainTask::PsomPipelineLauncher

  # Returns the PSOM subtasks.
  def psom_subtasks #:nodoc:
    lt = self.launch_time # task batch identifier
    return CbrainTask::PsomSubtask.where(:id => -999) unless lt && self.id # default set to match NO tasks
    CbrainTask::PsomSubtask.where( :launch_time => lt ) # active record relation
  end

end

