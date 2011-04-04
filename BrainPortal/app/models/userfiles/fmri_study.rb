
#
# CBRAIN Project
#
# $Id$
#

# This abstract class represents a FileCollection meant to model a fMRI study.
# File structure details are to be defined precisely in subclasses.
class FmriStudy < FileCollection

  Revision_info="$Id$"

  def self.pretty_type #:nodoc:
    "fMRI Study"
  end

  # Returns a list of subject names in the study.
  # Default to all subjects.
  # Can be restricted to a subset by providing some +options+.
  # Options:
  #   :sessions => [list of sessions]
  def list_subjects(options={})
    []
  end

  # Returns a list of session names in the study.
  # Default to all sessions accross all subjects.
  # Can be restricted to a subset by providing some +options+.
  # Options:
  #   :subjects => [list of subjects]
  def list_sessions(options={})
    []
  end

  # Anatomical files.
  # Returns a list of relative basenames in the study.
  # Default to all subjects and all sessions in the study.
  # Can be restricted to a subset by providing some +options+.
  # Options:
  #   :subjects => [list of subjects]
  #   :ext      => /regexp/ of file extensions
  def list_anat_files(options={})
    []
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
    []
  end

end

