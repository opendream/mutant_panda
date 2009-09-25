require File.join( File.dirname(__FILE__), "..", "spec_helper" )

describe Generic do
  
  before(:all) do
    Merb::Config.use do |p|
      # ...
    end
  end
  
  before :each do
    @tempfile = mock(File, :filename=>"tmpfile", :path=>"/tmp/tmpfile")
    @file = Mash.new({"content_type"=>"text/plain", "size"=>100, "tempfile"=>@tempfile, "filename"=>"test.txt"})

    @asset = Asset.new
    @asset.client = "test_client"
    @asset.accept_upload(@file)

    FileUtils.stub!(:mv)
    @video.stub!(:read_metadata)
    @video.stub!(:save)
  end
  
  describe "text file should cast to a Generic"

end