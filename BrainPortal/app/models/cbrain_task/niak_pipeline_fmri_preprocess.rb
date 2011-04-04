
#
# CBRAIN Project
#
# PortalTask model NiakPipelineFmriPreprocess
#
# $Id$
#

# A subclass of CbrainTask to launch NiakPipelineFmriPreprocess.
class CbrainTask::NiakPipelineFmriPreprocess < PortalTask

  Revision_info="$Id$"

  def pretty_name #:nodoc:
    "NIAK fMRI Preprocessing"
  end

  def self.default_launch_args #:nodoc:
    {
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
        :interpolation => "tricubic", # 'sinc' or 'tricubic'
        :voxel_size    => "3",
        :flag_skip     => "0"
      },

      :smooth_vol => {
        :fwhm      => "6",
        :flag_skip => "0"
      }

    }
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



    # -------------------------------------------------------------------
    params_errors.add('slice_timing[type_acquisition]', "has invalid value.") unless
      params[:slice_timing][:type_acquisition] =~ /^(interleaved|interleaved ascending|interleaved descending|sequential|sequential ascending|sequential descending)$/

    params_errors.add('slice_timing[type_scanner]', "has invalid value.") unless
      params[:slice_timing][:type_scanner] =~ /^[\w\s\.]$/

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
      params[:resample_vol][:interpolation] =~ /^(sinc|tricubic)$/

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
      'slice_timing[delay_in_tr]'             => "{delay_in_tr}",

      'motion_correction[suppress_vol]'       => "{suppres_vol}",
      'motion_correction[session_ref]'        => "{session_ref}",

      't1_preprocess[nu_correct][distance]'   => "nu_correct distance",

      'anat2func[init]'                       => "{init}",

      'time_filter[hp]'                       => "{hp}",
      'time_filter[lp]'                       => "{lp}",

      'corsica[sica][nb_comp]'                => "{Corsica sica nb_comp}",
      'corsica[threshold]'                    => "{threshold}",

      'resample_vol[interpolation]'           => "{interpolation}",
      'resample_vol[voxel_size]'              => "{voxel_size}",

      'smooth_vol[fwhm]'                      => "{fwhm}"
    }
  end

  def final_task_list #:nodoc:
    file_ids = params[:interface_userfile_ids]
    
    task_list = []
    file_ids.each do |id|
      mj = self.clone
      mj.params[:interface_userfile_ids] = [ id ]
      task_list << mj
    end
    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :subtask_ids => true, :outfile_id => true }
  end

end

