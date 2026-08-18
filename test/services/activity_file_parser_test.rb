require "test_helper"

class ActivityFileParserTest < ActiveSupport::TestCase
  def upload(name)
    File.open(Rails.root.join("test/fixtures/files/#{name}"))
  end

  test "parses a GPX file into distance, duration and start_date" do
    result = ActivityFileParser.new(upload("sample.gpx")).parse

    assert_equal "Corrida de teste", result[:name]
    assert_equal "Run", result[:sport_type]
    assert_equal 600, result[:duration]
    assert_equal 600, result[:moving_time]
    assert result[:distance] > 0
    assert_equal Time.parse("2026-08-01T08:00:00Z"), result[:start_date]
  end

  test "parses a TCX file summing lap distance and duration" do
    result = ActivityFileParser.new(upload("sample.tcx")).parse

    assert_equal "Run", result[:sport_type]
    assert_equal 5000.0, result[:distance]
    assert_equal 1500, result[:duration]
    assert_equal Time.parse("2026-08-01T08:00:00Z"), result[:start_date]
  end

  test "raises ParseError for content that is not XML" do
    assert_raises(ActivityFileParser::ParseError) do
      ActivityFileParser.new(upload("invalid.gpx")).parse
    end
  end

  test "raises ParseError for a GPX with no track points" do
    empty_gpx = Tempfile.new([ "empty", ".gpx" ])
    empty_gpx.write('<?xml version="1.0"?><gpx version="1.1"><trk><trkseg></trkseg></trk></gpx>')
    empty_gpx.rewind

    assert_raises(ActivityFileParser::ParseError) do
      ActivityFileParser.new(empty_gpx).parse
    end
  ensure
    empty_gpx.close
    empty_gpx.unlink
  end
end
