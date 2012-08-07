
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

# A subclass of CbrainTask to launch NiakPipelineFmriPreprocess.
class CbrainTask::NiakPipelineFmriPreprocess < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def pretty_name #:nodoc:
    "NIAK fMRI Preprocessing"
  end

  def self.default_launch_args #:nodoc:
    super.merge( # one day may inherit from a general superclass for Psom pipelines
    {
      :generate_meta_graph => "1",

      :output_name    => "",
      :size_output    => "quality_control",    # 'all' or 'quality_control'

      :slice_timing       => {
        :type_acquisition => "", # 'interleaved', 'interleaved ascending', 'interleaved descending', 'sequential', 'sequential ascending', 'sequential descending'
        :type_scanner     => "", # 'Siemens' or anything else
        :delay_in_tr      => "0",
        :flag_skip        => "0"
      },

      :motion_correction => {
        :suppress_vol => "0",
        :session_ref  => "",
        :flag_skip    => "0"
      },

      :t1_preprocess => {
        :nu_correct => {
          :distance => "50" # 50 (3T), 200 (1.5T)
        }
      },

      :anat2func => {
        :init => ""   # 'identity' or 'center'
      },

      :time_filter => {
        :hp => "0.01", # float or '-Inf'
        :lp => "inf" # float or 'Inf'
      },

      :corsica => {
        :sica      => {
          :nb_comp => "20"
        },
        :threshold => "0.15", # float
        :flag_skip => "0"
      },

      :resample_vol => {
        :interpolation => "trilinear", # 'trilinear', 'sinc' or 'tricubic'
        :voxel_size    => "3",
        :flag_skip     => "0"
      },

      :smooth_vol => {
        :fwhm      => "6",
        :flag_skip => "0"
      }

    })
  end
  


  def before_form #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids] || []

    cb_error "You need to select at least one #{FmriStudy.pretty_type}" if ids.size == 0

    unless ids.all? { |id| Userfile.find_by_id(id).is_a?(FmriStudy) }
      cb_error "This task needs to be run on collections structured as '#{FmriStudy.pretty_type}'."
    end
    
    ""
  end



  def after_form #:nodoc:
    params = self.params || {}

    float_regex = '\d*\.?\d+([eE][-+]?\d+)?'
    
    # -------------------------------------------------------------------
    params_errors.add(:output_name, "is not a proper file name.") unless
      Userfile.is_legal_filename?(params[:output_name])

    params_errors.add(:size_output, "has invalid value.") unless
      params[:size_output] =~ /^(all|quality_control)$/

    if FmriStudy.find_all_by_id(params[:interface_usefile_ids]).any? { |u| u.name == params[:output_name] && u.data_provider_id == ( self.results_data_provider_id || u.data_provider_id) }
      params_errors.add(:output_name, "is the same name of one of your input studies, and would crush it.")
    end



    # -------------------------------------------------------------------
    params_errors.add('slice_timing[type_acquisition]', "has invalid value.") unless
      params[:slice_timing][:type_acquisition] =~ /^(interleaved|interleaved ascending|interleaved descending|sequential|sequential ascending|sequential descending)$/

    params_errors.add('slice_timing[type_scanner]', "has invalid value.") unless
      params[:slice_timing][:type_scanner] =~ /^[\w\s\.]*$/

    params_errors.add('slice_timing[delay_in_tr]', "has invalid value.") unless
      params[:slice_timing][:delay_in_tr] =~ /^\s*\d+\s*$/



    # -------------------------------------------------------------------
    params_errors.add('motion_correction[suppress_vol]', "has invalid value.") unless
      params[:motion_correction][:suppress_vol] =~ /^\s*\d+\s*$/

    params_errors.add('motion_correction[session_ref]', "has invalid value.") unless
      params[:motion_correction][:session_ref] =~ /^[\w\.]+$/



    # -------------------------------------------------------------------
    params_errors.add('t1_preprocess[nu_correct][distance]', "has invalid value.") unless
      params[:t1_preprocess][:nu_correct][:distance] =~ /^\s*\d+\s*$/


    # -------------------------------------------------------------------
    params_errors.add('anat2func[init]', "has invalid value.") unless
      params[:anat2func][:init] =~ /^(identity|center)$/



    # -------------------------------------------------------------------
    params_errors.add('time_filter[hp]', "has invalid value.") unless
      params[:time_filter][:hp] =~ /^(-Inf|[-+]?#{float_regex})$/io

    params_errors.add('time_filter[lp]', "has invalid value.") unless
      params[:time_filter][:lp] =~ /^(Inf|[-+]?#{float_regex})$/io




    # -------------------------------------------------------------------
    params_errors.add('corsica[sica][nb_comp]', "has invalid value.") unless
      params[:corsica][:sica][:nb_comp] =~ /^\s*\d+\s*$/

    params_errors.add('corsica[threshold]', "has invalid value.") unless
      params[:corsica][:threshold] =~ /^#{float_regex}$/io



    # -------------------------------------------------------------------
    params_errors.add('resample_vol[interpolation]', "has invalid value.") unless
      params[:resample_vol][:interpolation] =~ /^(sinc|trilinear|tricubic)$/

    params_errors.add('resample_vol[voxel_size]', "has invalid value.") unless
      params[:resample_vol][:voxel_size] =~ /^\s*\d+\s*$/



    # -------------------------------------------------------------------
    params_errors.add('smooth_vol[fwhm]', "has invalid value.") unless
      params[:smooth_vol][:fwhm] =~ /^\s*\d+\s*$/

    ""
  end

  def self.pretty_params_names #:nodoc:
    {
      'output_name'                           => "Name of output file",
      'size_output'                           => "Desired output type",

      'slice_timing[type_acquisition]'        => "Type of acquisition",
      'slice_timing[type_scanner]'            => "Type of scanner",
      'slice_timing[delay_in_tr]'             => "Delay in TR",

      'motion_correction[suppress_vol]'       => "Suppress volumes",
      'motion_correction[session_ref]'        => "Session reference",

      't1_preprocess[nu_correct][distance]'   => "nu_correct distance",

      'anat2func[init]'                       => "Init",

      'time_filter[hp]'                       => "High pass",
      'time_filter[lp]'                       => "Low pass",

      'corsica[sica][nb_comp]'                => "Number of components",
      'corsica[threshold]'                    => "Threshold",

      'resample_vol[interpolation]'           => "Interpolation",
      'resample_vol[voxel_size]'              => "Voxel Size",

      'smooth_vol[fwhm]'                      => "FWHM"
    }
  end

  def final_task_list #:nodoc:
    file_ids = params[:interface_userfile_ids]
    
    task_list = []
    file_ids.each do |id|
      mj = self.clone
      mj.params[:interface_userfile_ids] = [ id ]
      study_name = Userfile.find(id).name
      mj.description = mj.description.blank? ? study_name : mj.description.sub(/\s*$/,"") + "\n\n#{study_name}"
      task_list << mj
    end
    task_list
  end

  def untouchable_params_attributes #:nodoc:
    super.merge( # maybe we'll create a psom_pipeline_launcher model on the portal side, one day
      { 
        :outfile_id       => true,
      }
    )
  end

end

