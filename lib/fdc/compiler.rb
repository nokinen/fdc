require 'builder'
require 'date'
require 'fdc/parser'

# Compile KML documents from a {Fdc::Parser}
class Fdc::Compiler
  
  # The compiled KML document
  attr_reader :kml
  attr_accessor :parser
  
  # Create a new instance
  # 
  # @param [Fdc::Parser] parser A parser from which the KML document should be compiled.
  def initialize(parser)
    @parser = parser
  end
  
  # Compile the KML document from the parsed IGC file.
  # 
  # @param [String] track_name The name of the KML track
  # @param [Boolean] clamp Whether the track should be clamped to the ground
  # @param [Boolean] extrude Whether the track should be extruded to the ground
  # @param [Boolean] gps Whether GPS altitude information should be used
  # @raise [RuntimeError] If the supplied parser is not ready
  def compile(track_name, clamp=false, extrude=false, gps=false)
    
    raise RuntimeError, "Parser not ready" unless @parser.ready?
    
    # Build HTML for balloon description
    html = Builder::XmlMarkup.new(:indent => 2)
    html.div :style => "width: 250;" do
      html.p do
        unless @parser.a_record[3].nil? then 
          html.strong "Device:"
          html.dfn @parser.a_record[3].strip
          html.br 
        end
      end
      html.p do
        @parser.h_records.each do |h|
          if h.include? "PLT" and not h[2].strip.empty? then 
            html.strong "Pilot:"
            html.dfn h[2].strip
            html.br
          end
          if h.include? "CID" and not h[2].strip.empty? then 
            html.strong "Competition ID:"
            html.dfn h[2].strip
            html.br
          end
          if h.include? "GTY" and not h[2].strip.empty? then 
            html.strong "Glider:"
            html.dfn h[2].strip
            html.br
          end
          if h.include? "GID" and not h[2].strip.empty? then
            html.strong "Glider ID:"
            html.dfn h[2].strip
            html.br
          end
          if h.include? "CCL" and not h[2].strip.empty? then 
            html.strong "Competition class:"
            html.dfn h[2].strip
            html.br 
          end
          if h.include? "SIT" and not h[2].strip.empty? then 
            html.strong "Site:"
            html.dfn h[2].strip
            html.br
          end
        end
      
        html.strong "Date:"
        html.dfn @parser.date_record[3..5].join(".")
        html.br
      end
    
      # Manufacturer-dependent L records
      case @parser.a_record[1]
      when "XSX"
        @parser.l_records.each do |l|
          if matches = l[1].scan(/(\w*):(-?\d+.?\d+)/) then 
            html.p do
              matches.each do |match|
                case match[0]
                when "MC"
                  html.strong "Max. climb:"
                  html.dfn match[1] << " m/s"
                  html.br
                when "MS"
                  html.strong "Max. sink:"
                  html.dfn match[1] << " m/s"
                  html.br
                when "MSP"
                  html.strong "Max. speed:"
                  html.dfn match[1] << " km/h"
                  html.br
                when "Dist"
                  html.strong "Track distance:"
                  html.dfn match[1] << " km"
                  html.br
                end
              end
            end
          end
        end
      end
    
    end
  
    # Build KML
    xml = Builder::XmlMarkup.new(:indent => 2)
    xml.instruct!
    xml.kml "xmlns" => "http://www.opengis.net/kml/2.2", "xmlns:gx" => "http://www.google.com/kml/ext/2.2" do
      xml.Placemark {
        xml.name track_name
        xml.Snippet :maxLines => "2" do
          xml.text! snippet
        end
        xml.description do
          xml.cdata! html.target!
        end
        xml.Style do
          xml.IconStyle do
            xml.Icon do 
              xml.href "http://earth.google.com/images/kml-icons/track-directional/track-0.png"
            end
          end
          xml.LineStyle do
            xml.color "99ffac59"
            xml.width "4"
          end
        end
        xml.gx:Track do
        
          clamp ? xml.altitudeMode("clampToGround") : xml.altitudeMode("absolute")
          extrude ? xml.extrude("1") : xml.extrude("0")
        
          @parser.b_records.each do |b_record|
             time = DateTime.new(2000 + @parser.date_record[5].to_i, @parser.date_record[4].to_i, @parser.date_record[3].to_i, 
              b_record[1].to_i, b_record[2].to_i, b_record[3].to_i)
             xml.when time
          end
          @parser.b_records.each do |b_record|
            coords = Fdc::GeoLocation.to_dec(b_record[5], b_record[4])
            gps ? coords << b_record[8].to_f : coords << b_record[7].to_f
            xml.gx :coord, coords.join(" ")
          end
        end
      }
    end
  
    @kml = xml.target!
  end
  
  private

  # Generate Snippet tag content
  def snippet
    summary = "Flight"
    @parser.h_records.each do |h|
      if h.include? "SIT" and not h[2].strip.empty? then 
        summary << " from #{h[2].strip}" 
      end
    end
    summary << " on #{@parser.date_record[3..5].join(".")}"
  end
  
end