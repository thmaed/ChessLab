import coremltools as ct, numpy as np, time
inp = {"tokens": np.zeros((1,64,97), dtype=np.float32), "self_elo": np.array([1500.], dtype=np.float32), "oppo_elo": np.array([1500.], dtype=np.float32)}
for name, cu in (("ALL", ct.ComputeUnit.ALL), ("CPU_ONLY", ct.ComputeUnit.CPU_ONLY), ("CPU_AND_NE", ct.ComputeUnit.CPU_AND_NE)):
    m = ct.models.MLModel("Maia3_5M.mlpackage", compute_units=cu)
    for _ in range(5): m.predict(inp)
    t=time.perf_counter(); N=50
    for _ in range(N): m.predict(inp)
    print(f"{name}: {(time.perf_counter()-t)/N*1000:.1f} ms")
# palettisation 8 bits
from coremltools.optimize.coreml import OpPalettizerConfig, OptimizationConfig, palettize_weights
m = ct.models.MLModel("Maia3_5M.mlpackage")
cfg = OptimizationConfig(global_config=OpPalettizerConfig(mode="kmeans", nbits=8))
m8 = palettize_weights(m, cfg); m8.save("Maia3_5M_8bit.mlpackage")
import subprocess; print("8-bit:", subprocess.run(["du","-sh","Maia3_5M_8bit.mlpackage"],capture_output=True,text=True).stdout.strip())
o1 = m.predict(inp)["move_logits"]; o2 = m8.predict(inp)["move_logits"]
print("max |Δlogit| fp16 vs 8-bit:", float(np.abs(np.asarray(o1)-np.asarray(o2)).max()))
