
#
# CBRAIN Project
#
# ClusterTask Model NiakPipelineFmriPreprocess
#
# $Id$
#

# A subclass of ClusterTask to run NiakPipelineFmriPreprocess.

require_dependency "#{CBRAIN::TasksPlugins_Dir}/psom_pipeline_launcher.rb"

class CbrainTask::NiakPipelineFmriPreprocess < CbrainTask::PsomPipelineLauncher

  Revision_info=CbrainFileRevision[__FILE__]

  def setup #:nodoc:
    svninfo_outerr = self.tool_config_system("svn info \"$NIAK_ROOT\" 2>&1")
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

