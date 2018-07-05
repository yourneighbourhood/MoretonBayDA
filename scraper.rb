require 'scraperwiki'
require 'mechanize'

# Scraping from Masterview 2.0

def scrape_page(page, comment_url)
  page.at("table.rgMasterTable").search("tr.rgRow,tr.rgAltRow").each do |tr|
    tds = tr.search('td').map{|t| t.inner_html.gsub("\r\n", "").strip}
    day, month, year = tds[2].split("/").map{|s| s.to_i}
    record = {
      "info_url" => (page.uri + tr.search('td').at('a')["href"]).to_s,
      "council_reference" => tds[1],
      "date_received" => Date.new(year, month, day).to_s,
      "description" => tds[3].gsub("&amp;", "&").split("<br>")[1].squeeze(" ").strip,
      "address" => tds[3].gsub("&amp;", "&").split("<br>")[0].gsub("\r", " ").gsub("<b>","").gsub("</b>","").squeeze(" ").strip,
      "date_scraped" => Date.today.to_s,
      "comment_url" => comment_url
    }
    #p record
    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  end
end

# Implement a click on a link that understands stupid asp.net doPostBack
def click(page, doc)
  return nil if doc.nil?
  
  js = doc["href"] || doc["onclick"]
  if js =~ /javascript:__doPostBack\('(.*)','(.*)'\)/
    event_target = $1
    event_argument = $2
    form = page.form_with(id: "aspnetForm")
    form["__EVENTTARGET"] = event_target
    form["__EVENTARGUMENT"] = event_argument
    form.submit
  elsif js =~ /return false;__doPostBack\('(.*)','(.*)'\)/
    nil
  else
    # TODO Just follow the link likes it's a normal link
    raise
  end
end

url = "http://pdonline.moretonbay.qld.gov.au/Modules/applicationmaster/default.aspx?page=found&1=thismonth&6=F"
comment_url = "mailto:mbrc@moretonbay.qld.gov.au"

agent = Mechanize.new

# Read in a page
page = agent.get(url)

current_page_no = 1
next_page_link = true

while next_page_link
  puts "Scraping page #{current_page_no}..."
  scrape_page(page, comment_url)

  current_page_no += 1
  next_page_link = page.at(".rgPageNext")
  page = click(page, next_page_link)
  next_page_link = nil if page.nil?
end
