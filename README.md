# QueState
There are a significant number of queueing model calculation programs on the internet which produce performance statistics such as the probability of blocking, but they rarely enumerate the model’s state probabilities. That is, the probability of 0, 1, 2, etc. customers in queue or in service. These state probabilities are the most fundamental results the model produces, and more importantly, represent the customer concurrency distribution. They answer the question; what are the chances there are “N” customers present in the queueing system? 

The “QueState” programs perform their queueing model calculations with a focus on providing customer concurrency information in addition to the usual performance statistics. Seven common queueing models plus the Normal distribution are supported in an open-source Perl script environment where results are produced in a spreadsheet friendly comma delimited format.
## Queueing Models
Using Kendall notation, the models are:
1. M/M/c - Markovian arrivals and service with c servers,
2. M/M/c/c - Markovian arrivals and distribution free service with c servers and no queueing,
3. M/M/c/c/N - Markovian arrivals and distribution free service with c servers, no queueing, and population limit,
4. M/M/c/k – Markovian arrivals and service with c servers and queue length limit,
5. M/M/c/N - Markovian arrivals and service with c servers and population limit,
6. M/M/inf – Poisson distribution ordinates,
7. M/M/inf/N – Binomial distribution ordinates,
8. Normal – Normal distribution ordinates.

## Program setup and execution
The QueState_doc.pdf file contains:
1. queueing model descriptions
2. program setup information
3. program execution instructions
4. output specifics
5. results summary

The results summary is a figure taken from the QueState_doc.xlsx spreadsheet included in this repository. The model Perl scripts are in the bin directory and the demo directory is set up with an example test case for each of them.
## Concurrency
The state probabilities produced by these queueing model programs map to the user request concurrency statistics calculated by the web-generator-toolkit2 software and may be a useful modeling substitute for those statistics when load testing data is unavailable.
## References
\[1.\] A. O. Allen, “Probability, Statistics, and Queueing Theory”, Academic Press, Inc., Orlando, Florida, 1978.
\[2.\] R. B. Cooper, “Introduction to Queueing Theory”, Elsevier Science Publishing Co., Inc, New York, N.Y., (1984).
\[3.\] W. C. Giffin, “Queueing: Basic Theory and Applications”, Grid, Inc, Columbus, Ohio, 1978.
\[4.\] L. Kleinrock, “Queueing Systems Volume 1 and 2”, John Wiley & Sons, New York, N.Y., (1975).
