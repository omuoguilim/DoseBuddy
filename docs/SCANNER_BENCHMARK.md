# Prescription scanner baseline and retest

The initial manual check used ten fictional label screenshots uploaded through
the iOS simulator. No manual field corrections were included in scoring. Each
label had three equally weighted checks: medication name, strength including
unit, and complete directions. Case and presentational whitespace were ignored;
spaces inserted inside a name and missing direction words were errors.

| Trial | Name | Strength and unit | Directions | Correct |
| --- | --- | --- | --- | --- |
| 1 Samplemed | Incorrect (Samp Lemed) | Correct | Correct | 2/3 |
| 2 Testora | Correct | Correct | Correct | 3/3 |
| 3 Demorin | Correct | Correct | Correct | 3/3 |
| 4 Demo Cream | Correct | Correct | Correct | 3/3 |
| 5 Demo-Liquid | Correct | Correct | Correct | 3/3 |
| 6 Testorin, separate strength line | Incorrect (Strength:) | Correct | Correct | 2/3 |
| 7 Trialmed, wrapped instructions | Correct | Correct | Incorrect (truncated) | 2/3 |
| 8 DEMOTAB, uppercase and 100mg | Correct | Correct | Correct | 3/3 |
| 9 Examplemed, quantity first | Correct | Correct | Correct | 3/3 |
| 10 Finalmed, Use instructions | Incorrect (Fina lmed) | Correct | Incorrect (blank) | 1/3 |

Baseline: 25/30 fields (83.3%), 6/10 fully correct labels, 7/10 names,
10/10 strengths and units, and 8/10 complete directions.

The extraction changes address labelled strength on a separate line, wrapped
directions and instructions beginning with Use. They do not retrain Apple's
Vision model or guess corrections to recognized medication names.

`test/prescription_extraction_regression_test.dart` tests extraction from text.
It is not an image-recognition accuracy benchmark. Its synthetic text cases are
development/regression fixtures, not an independent evaluation set.

After installing the update, upload the same ten ORIGINAL images once each and
record all fields before correction. Keep the baseline and retest separately.
Then use fresh fictional labels to check whether the behavior generalizes.
Report original-image retest results separately from fresh-label results.
Do not infer time saved (not measured), real-prescription accuracy, clinical
validation, or production reliability from this small screenshot check.
