#!/usr/bin/ruby                                                                           

require "rexml/document"

locationforxml = ARGV[0]
locationofresults = ARGV[1] || "/tmp"
typeoflock = ARGV[2]

@RESULTSFILE = "#{locationofresults}/deletewhilelockedtest.results"
@XMLFILE = "#{locationforxml}/deletewhilelockedtest.xml"

doc = REXML::Document.new
xmldoc = doc.add_element("testsuite")
xmldoc.attributes["name"] = "DELETE WHILE LOCKED TEST"

@contents = ""
File.open(@RESULTSFILE, "r") do |file|
    lines = file.readlines
    @contents = lines.join
end

@failed = 0

# Parse the first test
test = xmldoc.add_element("testcase")
test.attributes["name"] = "DELETE WHILE LOCKED TEST ALL"
if @contents.match(/.*SUCCESS.*/m)
    test.add_element("success")
else
    @element = test.add_element("failure")
    @failed = @failed + 1
    @element.attributes["message"] = @contents
end

stdout = xmldoc.add_element("system-out")
stdout.text = @contents

xmldoc.add_attribute("tests", 1)
xmldoc.add_attribute("failures", @failed)

File.open(@XMLFILE, "w") do |file|
        file.write(xmldoc)
end
