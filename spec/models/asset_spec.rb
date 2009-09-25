require File.join( File.dirname(__FILE__), "..", "spec_helper" )

describe Asset do
  
  before(:all) do
    Merb::Config.use do |p|
      p[:store_base_url] = "mutant_panda.th"
    end
  end
  
  before :each do
    @asset = mock_asset
    
    Store.stub!(:set).and_return(true)
    Store.stub!(:delete).and_return(true)
  end
  
  describe "new" do
    it "should save properly" do
      lambda {
        asset = Asset.new
        asset.client = "test_client"
        asset.save
      }.should change { Asset.all.size }.by(1)
    end
    
    it "should return an empty" do
      asset = Asset.new
      asset.client = "test_client"
      asset.save
      asset.should be_empty
    end
  end
  
  # Attr helpers
  # ============
  
  describe "obliterate!" do
    before :each do
      @encoding = Video.new
      @encoding.filename = 'abc.flv'
      
      @video.should_receive(:encodings).and_return([@encoding])
      
      @video.stub!(:destroy)
      @encoding.stub!(:destroy)
    end
    

  
  # Uploads
  # =======
  
  describe "initial_processing" do
    before(:each) do
      @tempfile = mock(File, :filename => "tmpfile", :path => "/tmp/tmpfile")
      
      @file = Mash.new({"content_type"=>"video/mp4", "size"=>100, "tempfile" => @tempfile, "filename" => "file.mov"})
      @video.status = 'empty'
      
      FileUtils.stub!(:mv)
      @video.stub!(:read_metadata)
      @video.stub!(:save)
    end
    
    it "should raise NotValid if video is not empty" do
      @video.status = 'original'
      
      lambda {
        @video.initial_processing(@file)
      }.should raise_error(Video::NotValid)
      
      @video.status = 'empty'
      
      lambda {
        @video.initial_processing(@file)
      }.should_not raise_error(Video::NotValid)
    end
    
    it "should set filename and original_filename" do
      @video.should_receive(:id).and_return('1234')
      @video.should_receive(:filename=).with("1234.mov")
      @video.should_receive(:original_filename=).with("file.mov")
      
      @video.initial_processing(@file)
    end
    
    it "should move file to tempoary location" do
      FileUtils.should_receive(:mv).with("/tump/tmpfile", "/tmp/abc.mov")
      
      @video.initial_processing(@file)
    end
    
    it "should read metadata" do
      @video.should_receive(:read_metadata).and_return(true)
      
      @video.initial_processing(@file)
    end
    
    it "should save video" do
      @video.should_receive(:status=).with("original")
      @video.should_receive(:save)
      
      @video.initial_processing(@file)
    end
  end


end