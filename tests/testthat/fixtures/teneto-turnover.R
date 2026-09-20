# Reference values from teneto 0.5.3 for the Stage 3 A2/A3 fixture:
# undirected, nodes 0..3 (= A..D), contacts
#   (0,1,t=0) (1,2,t=0) (0,1,t=1) (2,3,t=1) (0,1,t=2) (1,2,t=2) (0,2,t=3)
#
# PROVENANCE. Regenerated and confirmed by a live teneto run on 2026-09-20
# (teneto 0.5.3, scipy 1.16.3, python 3.14.4), not transcribed.
#
#   teneto.networkmeasures.fluctuability runs unpatched.
#
#   teneto.networkmeasures.volatility does NOT run on scipy >= 1.11. teneto
#   builds its whole distance table eagerly (teneto/utils/utils.py:506-524),
#   so every name in it must resolve even though only 'hamming' is requested.
#   On scipy 1.16.3 TWO names are missing, not one: `kulsinski` AND `matching`.
#   (The Stage 3 spec named only `kulsinski`; `matching` was found by running
#   it.) Both were stubbed with functions that raise, so a stub reached by the
#   hamming path would surface as an error rather than a wrong number. The
#   genuine scipy `hamming` did the work.
#
# Hand-checked independently of teneto: the slices are {01,12}, {01,23},
# {01,12}, {02}; the pair domain is choose(4, 2) = 6; the symmetric differences
# have size 2, 2 and 3, giving 2/6, 2/6, 3/6 and a mean of 0.38889.
# Fluctuability's distinct pairs are {01, 12, 23, 02} = 4 over 7 edge events
# = 0.571428... Both derivations agree with the run.
list(
  fluctuability       = 0.5714285714285714,
  volatility_overall  = 0.38888888888888884,
  volatility_pertime  = c(0.3333333333333333, 0.3333333333333333, 0.5)
)
