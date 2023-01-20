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





# Set survey option for lonely PSUs





# Load datasets ---------------------------------------------------------------

# RX = Prescribed medicines (PMED) file (record = rx fill or refill)
# Conditions = Medical conditions file (record = medical condition)
# CLNK = Conditions-event link file (crosswalk between conditions and 
#        events, including PMED events)
# FYC = Full year consolidated file (record = MEPS sample person)


### Option 1 - load data files using read_MEPS from the MEPS package

# For PMED file, rename LINKIDX to EVNTIDX to merge with Conditions






### Option 2 - load Stata data files using read_dta from the haven package 

# Replace "C:/MEPS" below with the directory you saved the files to.
# For PMED file, rename LINKIDX to EVNTIDX to merge with Conditions

# pmed20 <- read_dta("C:/MEPS/h220a.dta") %>% rename(EVNTIDX=LINKIDX)
# cond20 <- read_dta("C:/MEPS/h222.dta")
# clnk20 <- read_dta("C:/MEPS/h220if1.dta")
# fyc20  <- read_dta("C:/MEPS/h224.dta")


# Select only needed variables ------------------------------------------------






# OPTIONAL: Look at table of ICD10s and CCSRs. 






# Prepare data for estimation -------------------------------------------------

# Subset condition records to hyperlipidemia (any CCSR = "END010") 






# Example to show someone with 'duplicate' hyperlipidemia conditions with
# different CONDIDXs.  This usually happens when the collapsed 3-digit 
# ICD10s are the same but the fully-specified ICD10s are different 
# (e.g., one person has different condition records for both E78.1 and 
# E78.5, which both map to END010 collapse to E78 on the PUF).







# Get de-duplicated list of people (unique DUPERSIDs) for people with 
# treated hyperlipidemia and create a person-level flag for any
# hyperlipidemia treatment (hl_flag)






# Merge this flag onto the FYC (person-level file) and set it to 0 for 
# people without hyperlipidemia







# QC: count of hl_flag=1 on FYC should be equal to the number of rows
# in hl_ppl and there should be no NAs





# QC: compare people *ever* diagnosed with hyperlipidemia (CHOLDX == 1) with
# those who were treated for hyperlipidemia in 2020 (hl_flag == 1)
# Note: there will always be noise in self-reported survey responses! 





# Merge hyperlipidemia conditions with PMED file, using CLNK as crosswalk






# QC: View top PMEDS for hyperlipidemia to see if they make sense






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







# De-duplicate 'duplicate' fills 






# Revisiting the example to show effect of de-duplicating






# For each person, count the number of unique drugs, number of fills, and 
# sum expenditures for treating hyperlipidemia. 
# Make a flag for people with a PMED purchase (hl_pmed_flag)







# Revisiting 'duplicate' fill example at the person level to show
# that we counted their fills and expenses only once 






# Merge onto FYC file to capture all Strata (VARSTR) and PSUs (VARPSU) for 
# all MEPS sample persons for correct variance estimation







# QC: check counts of hl_pmed_flag=1 and compare to the number of rows in
# drugs_by_pers.  Confirm all NAs were overwritten to zeroes. 





# QC: There should be no records where number of drugs > number of fills





# QC: There should be no records where hl_flag=0 and hl_pmed_flag=1 





# QC: There should be no records where hl_pmed_flag=0 and 
# (hl_drug_exp > 0 or number_hl_drugs > 0 or number_hl_fills > 0)





# Define survey design object  ------------------------------------------









# ESTIMATION ------------------------------------------------------------

### National Totals:

# !!Note: The total number of people treated for hyperlipidemia 
# does not exactly match the online data tools estimate because the online 
# data tools exclude informal home health visits from its estimate 
# (we did not exclude them here).  

# Calculate estimates for:
  # Total people treated for hyperlipidemia
  # Total people treated for HL w/ rx drugs
  # Total rx fills for hyperlipidemia
  # Total rx expenditures for hyperlipidemia
    





# Total number of people treated for hyperlipidemia with prescribed 
# medicines, BY SEX





### Per-person averages for people with at least one PMED fill for 
### hyperlipidemia (hl_pmed_flag = 1)

# Subset survey design object to those with at least one PMED fill
# for hyperlipidemia





# Calculate estimates for:
  # Avg # of fills for HL per person w/ HL fills
  # Avg # of drugs for HL per person w/ HL fills
  # Avg PMED exp for HL per person w/ HL fills







# Average PMED expenditures for hyperlipidemia among those with any rx fills
# for hyperlipidemia, BY SEX






# t-test of male vs. female for above estimates
# Note: The warning message is because some individuals have zero 
# person weight.





# Alternate t-test method using regression




