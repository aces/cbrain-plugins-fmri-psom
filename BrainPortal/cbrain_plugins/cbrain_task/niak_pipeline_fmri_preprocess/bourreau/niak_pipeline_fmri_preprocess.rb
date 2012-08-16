
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

require_dependency "#{CBRAIN::TasksPlugins_Dir}/psom_pipeline_launcher.rb"

# A subclass of PsomPipelineLauncher to run NiakPipelineFmriPreprocess.
class CbrainTask::NiakPipelineFmriPreprocess < CbrainTask::PsomPipelineLauncher

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def setup #:nodoc:
    svninfo_outerr = self.tool_config_system("cd \"$NIAK_ROOT\" ; svn info 2>&1")
    niak_rev = svninfo_outerr[0] =~ /Revision:\s+(\d+)/ ? Regexp.last_match[1] : "???"
    self.addlog("NIAK svn rev. #{niak_rev}")
    super
  end

  def save_results #:nodoc:
    params = self.params || {}

    fmri_study = FmriStudy.find(params[:interface_userfile_ids][0]) rescue nil
    self.results_data_provider_id ||= fmri_study.data_provider_id

    outfilename = params[:output_name]
    outfilename = "#{self.name}-P#{Process.pid}-T#{self.id}" if outfilename.blank? || ! Userfile.is_legal_filename?(outfilename)
    outfile = safe_userfile_find_or_new(FileCollection,
      :name             => outfilename,
      :data_provider_id => self.results_data_provider_id
    )
    outfile.save!
    outfile.cache_copy_from_local_file(self.pipeline_run_dir)

    self.addlog_to_userfiles_these_created_these( [ fmri_study ], [ outfile ] ) if fmri_study
    self.addlog("Saved #{outfilename}")
    params[:outfile_id] = outfile.id
    outfile.move_to_child_of(fmri_study) if fmri_study

    true
  end

  def recover_from_post_processing_failure #:nodoc:
    true
  end

end

