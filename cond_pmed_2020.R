# -----------------------------------------------------------------------------
#
# MEPS-HC: Prescribed medicine utilization and expenditures for 
# the treatment of hyperlipidemia
# 
# This example code shows how to link the MEPS-HC Medical Conditions file 
# to the Prescribed Medicines file for data year 2020 in order to estimate
# the following:
#   
# Event-level estimates:
#   - Total rx fills for the treatment of hyperlipidemia
#   - Total rx expenditures for the treatment of hyperlipidemia 
# 
# Person-level estimates 
#   - Total number of people treated for hyperlipidemia (any health care)
#   - Number of people treated for hyperlipidemia with prescribed medicines
#   - Mean number of rx fills and drugs per person for hyperlipidemia
#     treatment (among those with any rx fills for hyperlipidemia)
#   - Mean rx expenditures per person for the treatment of hyperlipidemia
#     (among those with any rx fills for hyperlipidemia)
# 
# Input files:
#   - h220a.dta        (2020 Prescribed Medicines file)
#   - h222.dta         (2020 Conditions file)
#   - h220if1.dta      (2020 CLNK: Condition-Event Link file)
#   - h224.dta         (2020 Full-Year Consolidated file)
# 
# Resources:
#   - CCSR codes: 
#   https://github.com/HHS-AHRQ/MEPS/blob/master/Quick_Reference_Guides/meps_ccsr_conditions.csv
# 
#   - MEPS-HC Public Use Files: 
#   https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp
# 
#   - MEPS-HC online data tools: 
#   https://datatools.ahrq.gov/meps-hc
#
# -----------------------------------------------------------------------------


# Install/load packages and set global options --------------------------------

# For each package that you don't already have installed, un-comment
# and run.  Skip this step if all packages below are already installed.

# install.packages("survey")     # for survey analysis
# install.packages("haven")      # for loading Stata (.dta) files
# install.packages("tidyverse")  # for data manipulation
# install.packages("devtools")   # for loading "MEPS" package from GitHub


# If MEPS package is not installed, un-comment and run to install

# library(devtools)
# install_github("e-mitchell/meps_r_pkg/MEPS")


# Load libraries

library(MEPS)     
library(survey)
library(tidyverse)
library(haven)


# Set survey option for lonely PSUs

options(survey.lonely.psu="adjust")


# Load datasets ---------------------------------------------------------------

# RX = Prescribed medicines (PMED) file (record = rx fill or refill)
# Conditions = Medical conditions file (record = medical condition)
# CLNK = Conditions-event link file (crosswalk between conditions and 
#        events, including PMED events)
# FYC = Full year consolidated file (record = MEPS sample person)


### Option 1 - load data files using read_MEPS from the MEPS package

# For PMED file, rename LINKIDX to EVNTIDX to merge with Conditions

pmed20 <- read_MEPS(year = 2020, type = "RX") %>% rename(EVNTIDX=LINKIDX)
cond20 <- read_MEPS(year = 2020, type = "Conditions")
clnk20 <- read_MEPS(year = 2020, type = "CLNK")
fyc20  <- read_MEPS(year = 2020, type = "FYC")


### Option 2 - load Stata data files using read_dta from the haven package 

# Replace "C:/MEPS" below with the directory you saved the files to.
# For PMED file, rename LINKIDX to EVNTIDX to merge with Conditions

# pmed20 <- read_dta("C:/MEPS/h220a.dta") %>% rename(EVNTIDX=LINKIDX)
# cond20 <- read_dta("C:/MEPS/h222.dta")
# clnk20 <- read_dta("C:/MEPS/h220if1.dta")
# fyc20  <- read_dta("C:/MEPS/h224.dta")


# Select only needed variables ------------------------------------------------

pmed20x <- pmed20 %>% select(DUPERSID, DRUGIDX, RXRECIDX, EVNTIDX, 
                             RXDRGNAM, RXXP20X)
cond20x <- cond20 %>% select(DUPERSID, CONDIDX, ICD10CDX, CCSR1X:CCSR3X)
fyc20x  <- fyc20  %>% select(DUPERSID, SEX, CHOLDX, VARSTR, VARPSU, 
                             PERWT20F)


# OPTIONAL: Look at table of ICD10s and CCSRs. 

cond_counts <- cond20x %>% 
  count(ICD10CDX, CCSR1X, CCSR2X, CCSR3X) 

View(cond_counts)


# Prepare data for estimation -------------------------------------------------

# Subset condition records to hyperlipidemia (any CCSR = "END010") 

hl <- cond20x %>% 
  filter(CCSR1X == "END010" | CCSR2X == "END010" | CCSR3X == "END010")


# Example to show someone with 'duplicate' hyperlipidemia conditions with
# different CONDIDXs.  This usually happens when the collapsed 3-digit 
# ICD10s are the same but the fully-specified ICD10s are different 
# (e.g., one person has different condition records for both E78.1 and 
# E78.5, which both map to END010 collapse to E78 on the PUF).

dup_hl <- hl[duplicated(hl$DUPERSID), ]

hl %>% filter(DUPERSID=='2320134102')


# Get de-duplicated list of people (unique DUPERSIDs) for people with 
# treated hyperlipidemia and create a person-level flag for any
# hyperlipidemia treatment (hl_flag)

hl_ppl <- hl %>% 
  select(DUPERSID) %>% 
  distinct %>% 
  mutate(hl_flag = 1)


# Merge this flag onto the FYC (person-level file) and set it to 0 for 
# people without hyperlipidemia

fyc_hl <- fyc20x %>% 
  left_join(hl_ppl, by = "DUPERSID") %>%
  replace_na(list(hl_flag = 0)) 


# QC: count of hl_flag=1 on FYC should be equal to the number of rows
# in hl_ppl and there should be no NAs

table(fyc_hl$hl_flag, useNA="always")


# Merge hyperlipidemia conditions with PMED file, using CLNK as crosswalk

hl_merged <- hl %>%
  inner_join(clnk20, by = c("DUPERSID", "CONDIDX")) %>% 
  inner_join(pmed20x, by = c("DUPERSID", "EVNTIDX")) 


# QC: View top PMEDS for hyperlipidemia to see if they make sense

hl_merged %>% 
    count(ICD10CDX, RXDRGNAM) %>% 
    arrange(-n)


# Because some people can have multiple CONDIDX values for hyperlipidemia
# as shown in the example above, and each of these different CONDIDX IDs
# can link to the same rx fills, it is necessary to de-duplicate on 
# the unique fill identifier RXRECIDX within a person who has 
# hyperlipidemia.

# For example, the same drug/fill can link to both E78.1 and E78.5.  

# An example illustrating the above issue.  Note that there are 'duplicate'
# RXRECIDX (fill IDs) repeated across two different CONDIDX values for the 
# same person because this person has 'duplicate' hyperlipidemia records
# and some fills are linked to both CONDIDX values for hyperlipidemia.

hl_merged %>% 
  filter(DUPERSID == "2320134102") %>% 
  select(DUPERSID, CONDIDX, RXRECIDX, RXDRGNAM, ICD10CDX, CCSR1X) 


# De-duplicate 'duplicate' fills 

hl_dedup <- hl_merged %>% 
  distinct(DUPERSID, RXRECIDX, .keep_all=T)


# Revisiting the example to show effect of de-duplicating

hl_dedup %>% 
  filter(DUPERSID == "2320134102") %>%
  select(DUPERSID, CONDIDX, RXRECIDX)


# For each person, count the number of unique drugs, number of fills, and 
# sum expenditures for treating hyperlipidemia. 
# Make a flag for people with a PMED purchase (hl_pmed_flag)

drugs_by_pers <- hl_dedup %>% 
  group_by(DUPERSID) %>% 
  summarize(
    number_hl_drugs = n_distinct(DRUGIDX),
    number_hl_fills = n_distinct(RXRECIDX),
    hl_drug_exp = sum(RXXP20X)) %>% 
  mutate(hl_pmed_flag = 1)


# Revisiting 'duplicate' fill example at the person level to show
# that we counted their fills and expenses only once 

drugs_by_pers %>% 
  filter(DUPERSID == "2320134102")


# Merge onto FYC file to capture all Strata (VARSTR) and PSUs (VARPSU) for 
# all MEPS sample persons for correct variance estimation

fyc_hl_merged <- fyc_hl %>% 
  left_join(drugs_by_pers, by="DUPERSID") %>% 
  replace_na(
    list(number_hl_drugs = 0,
         number_hl_fills = 0,
         hl_pmed_flag = 0,
         hl_drug_exp = 0))


# QC: check counts of hl_pmed_flag=1 and compare to the number of rows in
# drugs_by_pers.  Confirm all NAs were overwritten to zeroes. 

table(fyc_hl_merged$hl_pmed_flag, useNA="always")


# QC: There should be no records where number of drugs > number of fills

fyc_hl_merged %>% filter(number_hl_drugs > number_hl_fills) 

# QC: There should be no records where hl_flag=0 and hl_pmed_flag=1 

fyc_hl_merged %>% filter(hl_flag==0 & hl_pmed_flag==1)

# QC: There should be no records where hl_pmed_flag=0 and 
# (hl_drug_exp > 0 or number_hl_drugs > 0 or number_hl_fills > 0)

fyc_hl_merged %>% 
    filter(hl_pmed_flag==0 & 
       (hl_drug_exp > 0 | number_hl_drugs > 0 | number_hl_fills > 0))


# Define survey design object  ------------------------------------------

meps_dsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~PERWT20F,
  data = fyc_hl_merged,
  nest = TRUE) 


# ESTIMATION ------------------------------------------------------------

### National Totals:

# !!Note: The total number of people treated for hyperlipidemia 
# does not exactly match the online data tools estimate because the online 
# data tools exclude informal home health visits from its estimate 
# (we did not exclude them here).  
    
svytotal(~hl_flag +          # Total people treated for hyperlipidemia
           hl_pmed_flag +    # Total people treated for HL w/ rx drugs
           number_hl_fills + # Total rx fills for hyperlipidemia
           hl_drug_exp,      # Total rx expenditures for hyperlipidemia
           design=meps_dsgn)

    
# Total number of people treated for hyperlipidemia with prescribed 
# medicines, BY SEX

svyby(~hl_pmed_flag, ~factor(SEX), design=meps_dsgn, svytotal)

    
### Per-person averages for people with at least one PMED fill for 
### hyperlipidemia (hl_pmed_flag = 1)

# Subset survey design object to those with at least one PMED fill
# for hyperlipidemia

hl_pmed_dsgn <- subset(meps_dsgn, hl_pmed_flag == 1)


# Estimation of means among people with at least one PMED fill for
# hyperlipidemia 

svymean(~number_hl_fills +    # Avg # of fills for HL per person w/ HL fills
          number_hl_drugs +   # Avg # of drugs for HL per person w/ HL fills
          hl_drug_exp,        # Avg PMED exp for HL per person w/ HL fills
          design = hl_pmed_dsgn) 


# Average PMED expenditures for hyperlipidemia among those with any rx fills
# for hyperlipidemia, BY SEX

svyby(~hl_drug_exp, ~factor(SEX), design=hl_pmed_dsgn, svymean)
    

# t-test of male vs. female for above estimates
# Note: The warning message is because some individuals have zero 
# person weight.

svyttest(hl_drug_exp ~ factor(SEX), design=hl_pmed_dsgn)


# Alternate t-test method using regression

summary(svyglm(hl_drug_exp ~ factor(SEX), design=hl_pmed_dsgn))


