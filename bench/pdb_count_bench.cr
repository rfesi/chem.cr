require "../src/chem"
require "benchmark"

system = Chem::PDB.parse "bench/data/1ake.pdb"

Benchmark.bm do |bm|
  bm.report("1AKE (3818 atoms)") do
    system.each_residue.count &.name.==("ALA")
  end
end
