
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

# A subclass of CbrainTask to launch PsomSubtask.
#
# Not meant to be launched directly by users, instead these tasks
# are entirely created on the Bourreau side by subclasses
# of CbrainTask::PsomPipelineLauncher (see BOURREAU side).
class CbrainTask::PsomSubtask < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.properties #:nodoc:
    { :cannot_be_edited => true }
  end

  def pretty_name #:nodoc:
    psom_name = (self.params || {})[:psom_job_name]
    return self.name if psom_name.blank?
    "PsomSubtask (#{psom_name})"
  end

  def before_form #:nodoc:
    cb_error "This task cannot be launched using the CBRAIN interface. The admin must have forgotten to set the tool's category to 'background'." # should never occur
  end

  def after_form #:nodoc:
    cb_error "This task cannot be edited using the CBRAIN interface." # should never occur
  end

  def self.untouchable_params_attributes #:nodoc:
    {
      :psom_job_id            => true,
      :psom_job_name          => true,
      :psom_pipe_desc_subdir  => true,
      :psom_job_script        => true,
      :psom_job_run_subdir    => true,
      :psom_ordered_idx       => true,
      :psom_predecessor_tids  => true,
      :psom_successor_tids    => true,
      :psom_main_pipeline_tid => true,
      :psom_graph_keywords    => true
    }
  end

end

