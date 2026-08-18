require "time"

class ActivityFileParser
  class ParseError < StandardError; end

  TCX_SPORT_MAP = { "Running" => "Run", "Biking" => "Ride" }.freeze
  EARTH_RADIUS_KM = 6371.0

  def initialize(file)
    @file = file
  end

  def parse
    doc = Nokogiri::XML(@file.read)
    doc.remove_namespaces!
    raise ParseError, "Arquivo XML inválido" if doc.root.nil?

    case doc.root.name
    when "gpx"
      parse_gpx(doc)
    when "TrainingCenterDatabase"
      parse_tcx(doc)
    else
      raise ParseError, "Formato não reconhecido (esperado GPX ou TCX)"
    end
  end

  private

  def parse_gpx(doc)
    points = doc.xpath("//trkpt").map do |pt|
      time_node = pt.at_xpath("time")
      {
        lat: pt["lat"].to_f,
        lon: pt["lon"].to_f,
        time: time_node && Time.parse(time_node.text)
      }
    end
    raise ParseError, "Nenhum ponto de rastreamento encontrado no GPX" if points.empty?

    times = points.map { |p| p[:time] }.compact

    build_result(
      name: doc.at_xpath("//trk/name")&.text,
      sport_type: doc.at_xpath("//trk/type")&.text,
      distance: total_distance_meters(points),
      duration: times.any? ? (times.max - times.min).to_i : 0,
      start_date: times.min
    )
  end

  def parse_tcx(doc)
    laps = doc.xpath("//Lap")
    raise ParseError, "Nenhuma volta (Lap) encontrada no TCX" if laps.empty?

    raw_sport = doc.at_xpath("//Activity")&.attr("Sport")
    start_date = begin
      Time.parse(laps.first["StartTime"].to_s)
    rescue ArgumentError
      nil
    end

    build_result(
      name: nil,
      sport_type: TCX_SPORT_MAP[raw_sport] || raw_sport,
      distance: laps.sum { |lap| lap.at_xpath("DistanceMeters")&.text.to_f },
      duration: laps.sum { |lap| lap.at_xpath("TotalTimeSeconds")&.text.to_f }.to_i,
      start_date: start_date
    )
  end

  def build_result(name:, sport_type:, distance:, duration:, start_date:)
    if distance.to_f <= 0 || duration.to_i <= 0
      raise ParseError, "Não foi possível calcular distância e duração do arquivo"
    end

    {
      name: name.presence || "Atividade importada",
      sport_type: sport_type.presence || "Run",
      distance: distance.round(2),
      duration: duration,
      moving_time: duration,
      average_speed: (distance / duration).round(3),
      start_date: start_date || Time.current
    }
  end

  def total_distance_meters(points)
    total_km = 0.0
    points.each_cons(2) { |a, b| total_km += haversine_km(a[:lat], a[:lon], b[:lat], b[:lon]) }
    (total_km * 1000).round(2)
  end

  def haversine_km(lat1, lon1, lat2, lon2)
    rad = Math::PI / 180
    dlat = (lat2 - lat1) * rad
    dlon = (lon2 - lon1) * rad
    a = Math.sin(dlat / 2)**2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dlon / 2)**2
    EARTH_RADIUS_KM * 2 * Math.asin(Math.sqrt(a))
  end
end
