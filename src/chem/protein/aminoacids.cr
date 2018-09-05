require "./aminoacid"

module Chem::Protein::AminoAcids
  ALA = AminoAcid.new "Alanine", "ALA", 'A'
  ARG = AminoAcid.new "Arginine", "ARG", 'R'
  ASN = AminoAcid.new "Asparagine", "ASN", 'N'
  ASP = AminoAcid.new "Aspartate", "ASP", 'D'
  CYS = AminoAcid.new "Cysteine", "CYS", 'C'
  GLN = AminoAcid.new "Glutamine", "GLN", 'Q'
  GLU = AminoAcid.new "Glutamate", "GLU", 'E'
  GLY = AminoAcid.new "Glycine", "GLY", 'G'
  HIS = AminoAcid.new "Histidine", "HIS", 'H'
  ILE = AminoAcid.new "Isoleucine", "ILE", 'I'
  LEU = AminoAcid.new "Leucine", "LEU", 'L'
  LYS = AminoAcid.new "Lysine", "LYS", 'K'
  MET = AminoAcid.new "Methonine", "MET", 'M'
  PHE = AminoAcid.new "Phenylalanine", "PHE", 'F'
  PRO = AminoAcid.new "Proline", "PRO", 'P'
  SER = AminoAcid.new "Serine", "SER", 'S'
  THR = AminoAcid.new "Threonine", "THR", 'T'
  TRP = AminoAcid.new "Tryptophan", "TRP", 'W'
  TYR = AminoAcid.new "Tyrosine", "TYR", 'Y'
  VAL = AminoAcid.new "Valine", "VAL", 'V'

  ASX = AminoAcid.new "Aspartate or Asparagine", "ASX", 'B'
  XLE = AminoAcid.new "Leucine or Isoleucine", "XLE", 'J'
  GLX = AminoAcid.new "Glutamine or Glutamate", "GLX", 'Z'
  PYL = AminoAcid.new "Pyrrolysine", "PYL", 'O'
  SEC = AminoAcid.new "Selenocysteine", "SEC", 'U'

  UNK = AminoAcid.new "Unknown", "UNK", 'X'
  XAA = UNK
end
