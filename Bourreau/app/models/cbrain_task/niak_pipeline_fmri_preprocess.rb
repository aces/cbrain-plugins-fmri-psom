
#
# CBRAIN Project
#
# ClusterTask Model NiakPipelineFmriPreprocess
#
# $Id$
#

# A subclass of ClusterTask to run NiakPipelineFmriPreprocess.
class CbrainTask::NiakPipelineFmriPreprocess < CbrainTask::PsomPipelineLauncher

  Revision_info="$Id$"

  def save_results #:nodoc:
    params = self.params || {}

    fmri_study = Userfile.find(params[:interface_userfile_ids][0]) rescue nil

    outfilename = params[:output_name]
    outfilename = "#{self.name}-P#{Process.pid}-T#{self.id}" if outfilename.blank? || ! Userfile.is_legal_filename?(outfilename)
    outfile = safe_userfile_find_or_new(FileCollection,
      :name             => outfilename,
      :data_provider_id => params[:data_provider_id]
    )
    outfile.save!
    outfile.cache_copy_from_local_file(self.pipeline_run_dir)

    self.addlog_to_userfiles_these_created_these( [ fmri_study ], [ outfile ] ) if fmri_study
    self.addlog("Saved #{outfilename}")
    params[:outfile_id] = outfile.id
    outfile.move_to_child_of(fmri_study) if fmri_study

    true
  end

end

