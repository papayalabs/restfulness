
require 'spec_helper'

describe Restfulness::Response do

  class ResponseResource < Restfulness::Resource
  end

  let :klass do
    Restfulness::Response
  end
  let :app do
    Class.new(Restfulness::Application) do
      routes do
        add 'project', ResponseResource
      end
    end
  end
  let :request do
    Restfulness::Request.new(app)
  end
  let :obj do
    klass.new(request)
  end

  describe "#initialize" do
    it "should assign request and headers" do
      expect(obj.request).to eql(request)
      expect(obj.headers).to eql({})
      expect(obj.status).to be_nil
      expect(obj.payload).to be_nil
    end
  end

  describe "#run" do
    context "without route" do
      it "should not do anything" do
        allow(request).to receive(:route).and_return(nil)
        allow(request).to receive(:uri).and_return(URI('http://test.com/test'))
        obj.run
        expect(obj.status).to eql(404)
        expect(obj.payload).to be_empty
        expect(obj.headers['Content-Type']).to be_nil
        expect(obj.headers['Content-Length']).to be_nil
      end
    end
    context "with route" do
      let :route do
        app.router.routes.first
      end

      it "should try to build resource and run it" do
        allow(request).to receive(:route).and_return(route)
        request.action = :get
        allow(request).to receive(:uri).and_return(URI('http://test.com/test'))
        resource = double(:Resource)
        expect(resource).to receive(:check_callbacks)
        expect(resource).to receive(:call).and_return({:foo => 'bar'})
        allow(route).to receive(:build_resource).and_return(resource)
        obj.run 
        expect(obj.status).to eql(200)
        str = "{\"foo\":\"bar\"}"
        expect(obj.payload).to eql(str)
        expect(obj.headers['Content-Type']).to match(/application\/json/)
        expect(obj.headers['Content-Length']).to eql(str.bytesize.to_s)
      end

      it "should call resource and set 204 result if no content" do
        allow(request).to receive(:route).and_return(route)
        request.action = :get
        allow(request).to receive(:uri).and_return(URI('http://test.com/test'))
        resource = double(:Resource)
        expect(resource).to receive(:check_callbacks)
        expect(resource).to receive(:call).and_return(nil)
        allow(route).to receive(:build_resource).and_return(resource)
        obj.run
        expect(obj.status).to eql(204)
        expect(obj.headers['Content-Type']).to be_nil
        expect(obj.headers['Content-Length']).to be_nil
      end

      it "should set string content type if payload is a string" do
        allow(request).to receive(:route).and_return(route)
        request.action = :get
        allow(request).to receive(:uri).and_return(URI('http://test.com/test'))
        resource = double(:Resource)
        expect(resource).to receive(:check_callbacks)
        expect(resource).to receive(:call).and_return("This is a text message")
        allow(route).to receive(:build_resource).and_return(resource)
        obj.run
        expect(obj.status).to eql(200)
        expect(obj.headers['Content-Type']).to match(/text\/plain/)
      end
    end

    context "with exceptions" do
      let :route do
        app.router.routes.first
      end

      it "should update the status and payload" do
        allow(request).to receive(:route).and_return(route)
        request.action = :get
        allow(request).to receive(:uri).and_return(URI('http://test.com/test'))
        resource = double(:Resource)
        txt = "This is a text error"
        allow(resource).to receive(:check_callbacks) do
          raise Restfulness::HTTPException.new(418, txt)
        end
        allow(route).to receive(:build_resource).and_return(resource)
        obj.run
        expect(obj.status).to eql(418)
        expect(obj.headers['Content-Type']).to match(/text\/plain/)
        expect(obj.payload).to eql(txt)
      end

      it "should update the status and provide JSON payload" do
        allow(request).to receive(:route).and_return(route)
        request.action = :get
        allow(request).to receive(:uri).and_return(URI('http://test.com/test'))
        resource = double(:Resource)
        err = {:error => "This is a text error"}
        allow(resource).to receive(:check_callbacks) do
          raise Restfulness::HTTPException.new(418, err)
        end
        allow(route).to receive(:build_resource).and_return(resource)
        obj.run
        expect(obj.status).to eql(418)
        expect(obj.headers['Content-Type']).to match(/application\/json/)
        expect(obj.payload).to eql(err.to_json)
      end

      context "for non http errors" do

        it "should catch error and provide result" do
          allow(request).to receive(:route).and_return(route)
          request.action = :get
          allow(request).to receive(:uri).and_return(URI('http://test.com/test'))
          resource = double(:Resource)
          allow(resource).to receive(:check_callbacks) do
            raise SyntaxError, 'Bad writing'
          end
          allow(route).to receive(:build_resource).and_return(resource)
          obj.run
          expect(obj.status).to eql(500)
        end

      end

    end

  end

end
