#!/usr/bin/ruby                                                                           

require "rexml/document"

locationforxml = ARGV[0]
locationofresults = ARGV[1] || "/tmp"

@RESULTSFILE = "#{locationofresults}/readdirplustest.results"
@XMLFILE = "#{locationforxml}/readdirplustest.xml"

doc = REXML::Document.new
xmldoc = doc.add_element("testsuite")
xmldoc.attributes["name"] = "READDIRPLUS TEST"

@contents = ""
File.open(@RESULTSFILE, "r") do |file|
  lines = file.readlines
  @contents = lines.join
end

pass=0
total=0
failed=0

# example: 65/65 tests succeeded.
@contents.scan(/^(\d+)\/(\d+)\stests\ssucceeded.*/) do |a,b|
    pass = a.to_i
    total = b.to_i
    failed = total - pass
end

# Parse the first test
test = xmldoc.add_element("testcase")
test.attributes["name"] = "READDIRPLUS TEST"
if total === pass
  test.add_element("success")
else
  @element = test.add_element("failure")
  @element.attributes["message"] = @contents
end

stdout = xmldoc.add_element("system-out")
stdout.text = @contents

xmldoc.add_attribute("tests", total)
xmldoc.add_attribute("failures", failed)

File.open(@XMLFILE, "w") do |file|
        file.write(xmldoc)
end
