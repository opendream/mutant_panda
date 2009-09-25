require File.join( File.dirname(__FILE__), "..", "spec_helper" )

describe FileStore do
  
  before :each do
    @store = FileStore.new
    
    @fp = mock(File)
    @fp.stub!(:write)
  end
  

  describe "set" do
    it "should move to file" do
      File.should_receive(:open).
        with('/tmp/abc.mov').and_return(:fp)
      FileUtils.should_receive(:mv).
        with('abc.mov', :fp, :access => :public_read).and_return(true)
      
      @store.set('abc.mov', '/tmp/abc.mov')
    end
  end

  
  describe "get" do
    it "should cp from store to local tmp dir" do
      File.should_receive(:open).with('/tmp/abc.mov', 'w').and_yield(@fp)
      FileUtils.should_receive(:cp).with(Merb::Config[:store_dir] + 'abc.mov', '/tmp/abc.mov')
      
      @store.get('abc.mov', '/tmp/abc.mov').should be_true
    end

    it "should error out when the file does not exists"
  end

  
  describe "delete" do
    it "should delete from file store"
    
    it "should error out when the file does not exists"
  end
  

  describe "url" do
    Merb::Config.use do |p|
      p[:store_base_url] = "mutant_panda.th"
    end
    
    it "should convert the key into a url" do
      @store.url('foo.mov').
        should == ('http://mutant_panda.th/foo.mov')
    end
  end
  
end
