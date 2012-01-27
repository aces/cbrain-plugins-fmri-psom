
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

# This abstract class represents a FileCollection meant to model a fMRI study.
# File structure details are to be defined precisely in subclasses.
class FmriStudy < FileCollection

  Revision_info=CbrainFileRevision[__FILE__]

  def self.pretty_type #:nodoc:
    "fMRI Study"
  end

  # Returns a list of subject names in the study.
  # Default to all subjects.
  # Can be restricted to a subset by providing some +options+.
  # Options:
  #   :sessions => [list of sessions]
  def list_subjects(options={})
    cb_error "Method not implemented in subclass."
  end

  # Returns a list of session names in the study.
  # Default to all sessions accross all subjects.
  # Can be restricted to a subset by providing some +options+.
  # Options:
  #   :subjects => [list of subjects]
  def list_sessions(options={})
    cb_error "Method not implemented in subclass."
  end

  # Anatomical files.
  # Returns a list of relative basenames in the study.
  # Default to all subjects and all sessions in the study.
  # Can be restricted to a subset by providing some +options+.
  # Options:
  #   :subjects => [list of subjects]
  #   :ext      => /regexp/ of file extensions
  def list_anat_files(options={})
    cb_error "Method not implemented in subclass."
  end
  
  # Scan files.
  # Returns a list of scan relative basenames in the study.
  # Default to all subjects and all sessions in the study.
  # Can be restricted to a subset by providing some +options+.
  # Options:
  #   :subjects => [list of subjects]
  #   :sessions => [list of sessions]
  #   :ext      => /regexp/ of file extensions
  def list_scan_files(options={})
    cb_error "Method not implemented in subclass."
  end

end

