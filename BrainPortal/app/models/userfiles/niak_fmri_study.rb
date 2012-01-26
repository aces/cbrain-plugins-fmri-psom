
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

# This class represents a FileCollection meant to model a fMRI study
# structured according to the conventions used by NIAK.
class NiakFmriStudy < FmriStudy

  Revision_info=CbrainFileRevision[__FILE__]

  def self.pretty_type #:nodoc:
    "NIAK fMRI Study"
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

  def list_anat_files(options = {}) #:nodoc:
    subs      = all_subjects
    filt_subs = looked_for(options[:subjects])
    results   = []
    subs.each do |sub|
      next if filt_subs.size > 0 && ! filt_subs[sub]
      anatlist = list_files("#{sub}/anatomy", :regular).map { |e| Pathname.new(e.name).basename.to_s }
      if (! options[:ext].blank?) && options[:ext].is_a?(Regexp)
        anatlist = anatlist.select { |scan| scan.match(options[:ext]) }
      end
      anatlist.each { |scan| results << "#{sub}/anatomy/#{scan}" }
    end
    results
  end

  def list_scan_files(options = {}) #:nodoc:
    subs      = all_subjects
    filt_subs = looked_for(options[:subjects])
    filt_sess = looked_for(options[:sessions])
    results   = []
    subs.each do |sub|
      next if filt_subs.size > 0 && ! filt_subs[sub]
      sesslist = all_sessions_for_subject(sub)
      sesslist.each do |sess|
        next if filt_sess.size > 0 && ! filt_sess[sess]
        scanlist = list_files("#{sub}/BOLD/#{sess}", :regular).map { |e| Pathname.new(e.name).basename.to_s }
        if (! options[:ext].blank?) && options[:ext].is_a?(Regexp)
          scanlist = scanlist.select { |scan| scan.match(options[:ext]) }
        end
        scanlist.each { |scan| results << "#{sub}/BOLD/#{sess}/#{scan}" }
      end
    end
    results
  end

  private

  def all_subjects #:nodoc:
    @_fmri_all_subjects ||= list_files(:top, :directory).map { |e| Pathname.new(e.name).basename.to_s }
  end

  def all_sessions_for_subject(subject) #:nodoc:
    list_files("#{subject}/BOLD", :directory).map { |e| Pathname.new(e.name).basename.to_s }
  end

  # Returns a quick hash for looking up if an element
  # is in array_or_elem (or is elem itself).
  def looked_for(array_or_elem) #:nodoc:
    return {} unless array_or_elem
    array_or_elem = [ array_or_elem ] unless array_or_elem.is_a?(Array)
    array_or_elem.index_by { |x| x }
  end

end

