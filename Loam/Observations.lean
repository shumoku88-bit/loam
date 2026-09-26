import Loam.Observations.Observation008
import Loam.Observations.Observation011
import Loam.Observations.Observation029
import Loam.Observations.Observation078
import Loam.Observations.Observation129
import Loam.Observations.Observation130
import Loam.Observations.Observation135
import Loam.Observations.Observation159
import Loam.Observations.Observation179
import Loam.Observations.Observation180
import Loam.Observations.Observation183
import Loam.Observations.Observation184
import Loam.Observations.Observation186
import Loam.Observations.Observation191
import Loam.Observations.Observation192
import Loam.Observations.Observation193
import Loam.Observations.Observation194
import Loam.Observations.Observation195
import Loam.Observations.Observation250
import Loam.Observations.Observation253
import Loam.Observations.Observation255
import Loam.Observations.Observation256
import Loam.Observations.Observation257
import Loam.Observations.Observation258
import Loam.Observations.Observation259
import Loam.Observations.Observation260
import Loam.Observations.Observation261
import Loam.Observations.Observation262
import Loam.Observations.Observation270
import Loam.Observations.Observation271
import Loam.Observations.Observation272
import Loam.Observations.Observation273
import Loam.Observations.Observation275
import Loam.Observations.Observation276
import Loam.Observations.Observation277
import Loam.Observations.Observation278
import Loam.Observations.Observation279
import Loam.Observations.Observation280
import Loam.Observations.Observation281
import Loam.Observations.Observation282
import Loam.Observations.Observation283
import Loam.Observations.StructuralS003
import Loam.Observations.StructuralS008
import Loam.Observations.Observation284
import Loam.Observations.Observation285
import Loam.Observations.Observation286
import Loam.Observations.Observation287
import Loam.Observations.Observation288
import Loam.Observations.Observation289
import Loam.Observations.Observation290
import Loam.Observations.Observation291
import Loam.Observations.Observation292
import Loam.Observations.Observation293
import Loam.Observations.Observation294
import Loam.Observations.Observation295
import Loam.Observations.Observation296
import Loam.Observations.Observation297
import Loam.Observations.Observation298
import Loam.Observations.Observation299
import Loam.Observations.Observation300
import Loam.Observations.Observation301
import Loam.Observations.Observation302
import Loam.Observations.Observation303
import Loam.Observations.Observation304
import Loam.Observations.Observation305
import Loam.Observations.Observation306
import Loam.Observations.Observation307
import Loam.Observations.Observation308
import Loam.Observations.Observation309
import Loam.Observations.Observation310
import Loam.Observations.Observation311
import Loam.Observations.Observation312
import Loam.Observations.Observation313
import Loam.Observations.Observation314
import Loam.Observations.Observation315
import Loam.Observations.Observation316
import Loam.Observations.Observation317
import Loam.Observations.Observation318
import Loam.Observations.Observation319
import Loam.Observations.Observation321
import Loam.Observations.Observation325
import Loam.Observations.Observation331
import Loam.Observations.Observation333
import Loam.Observations.Observation334
import Loam.Observations.Observation335
import Loam.Observations.Observation336
import Loam.Observations.Observation337
import Loam.Observations.Observation340
import Loam.Observations.Observation341
import Loam.Observations.Observation342
import Loam.Observations.Observation343
import Loam.Observations.Observation344
import Loam.Observations.Observation345
import Loam.Observations.Observation346
import Loam.Observations.Observation347
import Loam.Observations.Observation348
import Loam.Observations.Observation349

/-!
Research compaction note (2026-09-26): Observations 320, 322–324, 326–330
(except 325), 332, 338, and 339 were retired from the live witness umbrella after
their conclusions were absorbed by later terminal proofs, production promotion,
proof-carrying production types, and retained research prose. Observation 331 carries the terminal RowIndex
refinement; Observation 333 now carries the Stock-Flow quantity helper it needs
directly. Retired source remains available in Git history.
-/

/-!
# Selected live Lean research witnesses

This module gathers historical Lean observations that still justify keeping an
executable regression witness in the current repository. Practical code should
import `Loam.Core` instead.

This umbrella is **not** the durable kernel-proof trust surface. Some selected
observations intentionally use `native_decide` for finite executable witnesses.
Long-lived theorem assets selected for stronger checker/axiom qualification are
indexed separately by `Loam.DurableProofs`.

Superseded observations may graduate from this umbrella once their question,
witness, and conclusion remain recorded in research prose and Git history and a
later production invariant or observation has taken over their practical role.
-/
