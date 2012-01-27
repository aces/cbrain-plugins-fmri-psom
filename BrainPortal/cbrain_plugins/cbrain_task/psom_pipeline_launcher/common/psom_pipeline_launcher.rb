
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

class CbrainTask::PsomPipelineLauncher

  # Returns the PSOM subtasks.
  def psom_subtasks #:nodoc:
    lt = self.launch_time # task batch identifier
    return CbrainTask::PsomSubtask.where(:id => -999) unless lt && self.id # default set to match NO tasks
    CbrainTask::PsomSubtask.where( :launch_time => lt ) # active record relation
  end

end

