
#
# CBRAIN Project
#
# Study model based on the xnat.org structure
# See http://www.xnat.org for more info.
#
# $Id$
#

# This class represents a FileCollection meant to model a fMRI study
# structured according to the conventions described by http://www.xnat.org .
class XnatFmriStudy < FmriStudy

  Revision_info="$Id$"

  def self.pretty_type #:nodoc:
      "xnat.org Study"
  end

  def list_subjects(options = {}) #:nodoc:
      subs      = all_subjects
      filt_sess = looked_for(options[:sessions])
      return subs if filt_sess.size == 0
      subs.select do |sub|
        sesslist = all_sessions_for_subject(sub)
        sesslist.detect { |sess| filt_sess[sess] }
      end
  end
  
  def list_sessions(options = {}) #:nodoc:
    subs      = all_subjects
    filt_subs = looked_for(options[:subjects])
    sess_final = {}
    subs.each do |sub|
      next if filt_subs.size > 0 && ! filt_subs[sub]
      sesslist = all_sessions_for_subject(sub)
      sesslist.each { |sess| sess_final[sess] = true }
    end
    sess_final.keys.sort
  end

  # This methods works like the superclass methods in FmriStudy,
  # but with one more option:
  #
  #   :t_types => [ array of scan types ] # default: [ "T1", "T2" ]
  def list_anat_files(options = {}) 
    subs       = all_subjects
    filt_subs  = looked_for(options[:subjects])
    filt_sess  = looked_for(options[:sessions])
    filt_types = looked_for(options[:t_types] || [ "T1", "T2" ])                      
    scans_list = all_scans(subs, filt_subs, filt_sess, filt_types)                          
    results    = []
    scans_list.each do |scan_dir|
      resources_path = "#{scan_dir}/Resources"
      scanlist_type  = list_files("#{resources_path}", :directory).map { |e| Pathname.new(e.name).basename.to_s }
      scanlist_type.each do |scan_type|
        scanlist = list_files("#{resources_path}/#{scan_type}/Files", :regular).map { |e| Pathname.new(e.name).basename.to_s }
        if (! options[:ext].blank?) && options[:ext].is_a?(Regexp)
          scanlist = scanlist.select { |scan| scan.match(options[:ext]) }
        end
        scanlist.each { |scan| results << "#{resources_path}/#{scan_type}/Files/#{scan}" }
      end 
    end
    results
  end
    
  # This methods works like the superclass methods in FmriStudy,
  # but with one more option:
  #
  #   :scan_types => [ array of scan types ] # default: [ "fMRI" ]
  def list_scan_files(options = {}) #:nodoc:
    subs       = all_subjects
    filt_subs  = looked_for(options[:subjects])
    filt_sess  = looked_for(options[:sessions])
    filt_types = looked_for(options[:scan_type] || "fMRI")                      
    scans_list = all_scans(subs, filt_subs, filt_sess, filt_types)                          
    results    = []
    scans_list.each do |scan_dir|
      resources_path = "#{scan_dir}/Resources"
      scanlist_type  = list_files("#{resources_path}", :directory).map { |e| Pathname.new(e.name).basename.to_s }
      scanlist_type.each do |scan_type|
        scanlist = list_files("#{resources_path}/#{scan_type}/Files", :regular).map { |e| Pathname.new(e.name).basename.to_s }
        if (! options[:ext].blank?) && options[:ext].is_a?(Regexp)
          scanlist = scanlist.select { |scan| scan.match(options[:ext]) }
        end
        scanlist.each { |scan| results << "#{resources_path}/#{scan_type}/Files/#{scan}" }
      end 
    end
    results
  end
  
  private
  
  def all_subjects #:nodoc:
    list_files("Subjects", :directory).map {|e| Pathname.new(e.name).basename.to_s}
  end
  
  def all_sessions_for_subject(subject) #:nodoc:
      list_files("Subjects/#{subject}/Experiments", :directory).map { |e| Pathname.new(e.name).basename.to_s }
  end
  
  # Returns a quick hash for looking up if an element
  # is in array_or_elem (or is elem itself).
  def looked_for(array_or_elem) #:nodoc:
    return {} unless array_or_elem 
    array_or_elem = [ array_or_elem ] unless array_or_elem.is_a?(Array) 
    array_or_elem.index_by { |x| x }
  end

  def all_scans(subs, filt_subs, filt_sess, filt_types) #:nodoc:
    scans_list = []
    subs.each do |sub|
      next if filt_subs.size > 0 && ! filt_subs[sub]
      sesslist = all_sessions_for_subject(sub)
      sesslist.each do |sess|
        next if filt_sess.size > 0 && ! filt_sess[sess]
        scans_path   = "Subjects/#{sub}/Experiments/#{sess}/Scans"
        scanlist_dir = list_files("#{scans_path}", :directory).map { |e| Pathname.new(e.name).basename.to_s }
        scanlist_dir.each do |dir|
          next if filt_types.size > 0 && ! filt_types[dir]
          full_path = scans_path + "/" + dir
          scans_list << full_path
        end
      end
    end
    scans_list
  end
    
end

