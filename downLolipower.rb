#! /usr/bin/env ruby
#
# Alessandro Piccioli < alkawiz@gmail.com >
# License: GPLv3 or newer
#

require 'rubygems'
require 'net/http'
require 'hpricot'
require 'open-uri'
require 'digest/md5'
require 'getoptlong'

trap("INT") {
    puts "\nDownload interrupted!"
    exit 1
}
def pUsage()
    puts "Usage: downLolipower.rb [opts] title"
    puts "--startep [-s] n: first episode to download."
    puts "--endep [-e] n: last episode to download."
    puts "--help [-h]: print this help."
end
def parse_episode(x,file)
    animeurl = file[x].search("a").first[:href]
    filename = file[x].search("//span[@class='filename']").inner_html
    eptitle = file[x].search("i").inner_html
    checksum = file[x].search("//div[@class='metadata']").inner_html.grep(/MD5/)[0].split(":")[1].split("\n")[0]
    size = file[x].search("//span[@class='filesize']").inner_html.gsub("(","").gsub(",","").split(" ")[0].to_i
    return animeurl, filename, eptitle, checksum, size
end

def add_title(filename,title)
    extension = filename.sub(/.*\./,'')
    name = filename.sub(/\....$/,'')
    return "#{name} - #{title}.#{extension}"
end


opts = GetoptLong.new(
    ['--help', '-h', GetoptLong::NO_ARGUMENT],
    ['--startep', '-s', GetoptLong::REQUIRED_ARGUMENT],
    ['--endep', '-e', GetoptLong::REQUIRED_ARGUMENT])

url = 'http://www.lolipower.org/list.php'
startep = 1
neps = 0

begin
    opts.each do |opt,arg|
        case opt
            when '--help' then
                pUsage
                exit 0
            when '--startep' then
                startep = arg.to_i
            when '--endep' then
                neps = arg.to_i
        end
    end
rescue
    pUsage
    exit 0
end

if neps < startep && neps > 0
    puts "We do not live in a N/#{startep + 1}N world, you crazy bastard."
    exit 0
end

if ARGV.length != 1
    puts "Missing title."
    exit 0
end
title = ARGV.shift

uri = URI.parse(url)
http = Net::HTTP.new(uri.host)
animelist = http.get(uri.path)
data = Hpricot(animelist.body).search("//span[text()*='#{title}']")
ref = data.search("a")
if ref.size == 0 then
    puts "No anime with that title."
    exit 2
end
ref = ref.first[:href]
nepsmax = data.to_s.grep(/Eps/)[0].scan(/\d+/)[0].to_i 
neps = nepsmax if neps == 0 || neps > nepsmax || neps < starteps

i = 0 # episodes to skip due to possibile duplicated episodes
eptitle_prec = ''
(startep-1..neps-1).each do |x|
    animepage = Net::HTTP.start(uri.host).get("/#{ref}")
    file = Hpricot(animepage.body).search("//div[@class='file']")
    animeurl,filename,eptitle,checksum,size = parse_episode(x+i,file)
    while eptitle_prec == eptitle do
        i += 1
        animeurl,filename,eptitle,checksum,size = parse_episode(x+i,file)
    end
    if filename.sub(/.*\./,'') == "avi" then
        if file[x+i+1].search("i").inner_html == eptitle then
            i += 1
            animeurl,filename,eptitle,checksum,size = parse_episode(x+i,file)
        end
    end
    eptitle_prec = eptitle
    filename = add_title(filename,eptitle)
    if FileTest.exists?(filename) then
        digest = Digest::MD5.hexdigest(File.read(filename)).upcase
        if digest == checksum then
            puts "#{filename} already downloaded."
            next
        end
    end
    puts "Downloading #{filename}"
    comp = 0
    STDOUT.sync = true
    digest = Digest::MD5.new
    Net::HTTP.start(URI.parse(animeurl).host, '80') do |http|
        File.open(filename,'w') do |f|
            http.get(URI.parse(animeurl).path+'?'+URI.parse(animeurl).query) do |str|
                comp += str.size
                perc = "%0.1f" % (comp.to_f/size.to_f*100).to_s
                print "\r#{perc} %"
                digest = digest << str
                f.write(str)
            end
        end
    end
    puts ""
    # system("wget \'#{animeurl}\' -O \'#{filename}\' ")
    # system("curl \'#{animeurl}\' > \'#{filename}\' ")
    # open(filename, "w").write(open("#{animeurl}").read)
    # digest = Digest::MD5.hexdigest(File.read(filename)).upcase
    if digest.hexdigest.upcase != checksum then
        puts "#{filename} got damaged."
        next
    end
end
