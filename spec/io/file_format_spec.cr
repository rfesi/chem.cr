require "../spec_helper"

@[Chem::IO::FileType(format: CAD, ext: %w(cad))]
class CAD::Parser < Chem::IO::Parser(String)
  def parse : String
    "foo"
  end
end

@[Chem::IO::FileType(format: Image, ext: %w(bmp jpg png tiff))]
class Image::Writer < Chem::IO::Writer(String)
  def write(obj : String) : Nil; end
end

@[Chem::IO::FileType(format: License, ext: %w(lic), names: %w(SPEC LIC* *KE *any*))]
class License::Writer < Chem::IO::Writer(String)
  def write(obj : String) : Nil; end
end

describe Chem::IO::FileFormat do
  describe ".from_ext?" do
    it "returns file format based on file extension" do
      Chem::IO::FileFormat.from_ext?(".bmp").should eq Chem::IO::FileFormat::Image
      Chem::IO::FileFormat.from_ext?(".jpg").should eq Chem::IO::FileFormat::Image
      Chem::IO::FileFormat.from_ext?(".png").should eq Chem::IO::FileFormat::Image
      Chem::IO::FileFormat.from_ext?(".tiff").should eq Chem::IO::FileFormat::Image
      Chem::IO::FileFormat.from_ext?(".TIFF").should eq Chem::IO::FileFormat::Image
      Chem::IO::FileFormat.from_ext?(".cad").should eq Chem::IO::FileFormat::CAD
      Chem::IO::FileFormat.from_ext?(".CAD").should eq Chem::IO::FileFormat::CAD
    end

    it "returns nil for unknown file extension" do
      Chem::IO::FileFormat.from_ext?(".dfgkjh").should be_nil
    end
  end

  describe ".from_ext" do
    it "fails for unknown file extension" do
      expect_raises ArgumentError, "File format not found for .hei" do
        Chem::IO::FileFormat.from_ext ".hei"
      end
    end
  end

  describe ".from_filename" do
    it "fails for unknown filename" do
      expect_raises ArgumentError, "File format not found for foo.bar" do
        Chem::IO::FileFormat.from_filename "foo.bar"
      end
    end
  end

  describe ".from_filename?" do
    it "returns file format based on filename" do
      Chem::IO::FileFormat.from_filename?("img.tiff").should eq Chem::IO::FileFormat::Image
      Chem::IO::FileFormat.from_filename?("spec.cad").should eq Chem::IO::FileFormat::CAD
      Chem::IO::FileFormat.from_filename?("spec").should eq Chem::IO::FileFormat::License
      Chem::IO::FileFormat.from_filename?("license").should eq Chem::IO::FileFormat::License
      Chem::IO::FileFormat.from_filename?("license.key").should eq Chem::IO::FileFormat::License
    end

    it "returns nil for unknown filename" do
      Chem::IO::FileFormat.from_filename?("foo.bar").should be_nil
      Chem::IO::FileFormat.from_filename?("baz").should be_nil
    end
  end

  describe ".from_stem" do
    it "fails for unknown file stem" do
      expect_raises ArgumentError, "File format not found for UNKNOWN" do
        Chem::IO::FileFormat.from_stem "UNKNOWN"
      end
    end
  end

  describe ".from_stem?" do
    it "returns file format based on file stem" do
      %w(SPEC Spec spec LIC LICENSE LICENSE_MIT KE NAM_KE ANY AMANYLOC).each do |stem|
        Chem::IO::FileFormat.from_stem?(stem).should eq Chem::IO::FileFormat::License
      end
    end

    it "returns nil for unknown file stem" do
      %w(Specs LIKENSE NOTLIC KENOT KE_NOT UNKNOWN).each do |stem|
        Chem::IO::FileFormat.from_stem?(stem).should be_nil
      end
    end
  end

  describe "#extnames" do
    it "returns registered file extensions" do
      Chem::IO::FileFormat::Image.extnames.should eq [".bmp", ".jpg", ".png", ".tiff"]
      Chem::IO::FileFormat::CAD.extnames.should eq [".cad"]
    end
  end

  describe "#names" do
    it "returns registered file formats" do
      Chem::IO::FileFormat.names.includes?("CAD").should be_true
      Chem::IO::FileFormat.names.includes?("Image").should be_true
    end
  end
end
