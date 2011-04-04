
#
# CBRAIN Project
#
# Study model based on the OpenfMRI.org structure
# See http://openfmri.org/ for more info.
#
# $Id$
#

# This class represents a FileCollection meant to model a fMRI study
# structured according to the conventions described by openfmri.org .
class OpenFmriOrgStudy < FmriStudy

  Revision_info="$Id$"

  def self.pretty_type #:nodoc:
    "OpenfMRI.org Study"
  end
  
end

