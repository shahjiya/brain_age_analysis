---
title: "brainchart.io"
output: html_document
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```

## R Markdown

This is an R Markdown document. Markdown is a simple formatting syntax for authoring HTML, PDF, and MS Word documents. For more details on using R Markdown see <http://rmarkdown.rstudio.com>.

When you click the **Knit** button a document will be generated that includes both content as well as the output of any embedded R code chunks within the document. You can embed an R code chunk like this:

## Brainchart.io

Before running this script, make sure to use the brainvol.stats.sh script to extract the ventricles volume
## Load Libraries

```{r cars}
library(readxl)
library(openxlsx)
library(stringr)
library(dplyr)
library(readr)
```

Load necessary brainage template, demographic file, aseg and aparc files for brainAGE analysis. 

Change sex to "Male" or "Female" depending on analysis.

```{r}

#Load excel file
template_brainage <- read_csv("/KIMEL/tigrlab/scratch/jshah/brain_age_analysis/data/raw/brainchart.io.template.csv")
                                
sex <- "Female"

#Load Aseg file
aseg_data <- read_tsv("/KIMEL/tigrlab/scratch/jshah/brain_age_analysis/data/raw/00_group2_stats_tables/aseg.tsv")

#Load Brain Volume file
brainvol_data <- read_csv("/KIMEL/tigrlab/scratch/jshah/brain_age_analysis/data/raw/brainvol_data.csv")

#Load demographics file
TAY_demographics <- read_csv("/KIMEL/tigrlab/scratch/jshah/brain_age_analysis/data/raw/tay_mri_demo_summer2024.csv")

```
Function to clean and standardize subject IDs for the aseg, surface area, and thickness data. 

```{r}
#save the original column names
original_template_column_names <- colnames(template_brainage)

clean_subject_ids_tsv <- function(df) {
  colnames(df)[1] <- "clean_subject_id"  # Rename the first column to 'clean_subject_id'
  df %>%
    mutate(clean_subject_id = str_extract(clean_subject_id, "[0-9]{8}$"))  # Extract the last 8 digits of subject IDs
}

aseg_data_clean <- clean_subject_ids_tsv(aseg_data)
brainvol_data_clean <- clean_subject_ids_tsv(brainvol_data)
```

Function to clean demographic subject_IDs

```{r}
clean_subject_ids_demo <- function(df, subject_id) {
  df %>%
    mutate(clean_subject_id = str_extract(!!sym(subject_id), "[0-9]{8}$"))
}

TAY_demographics <- clean_subject_ids_demo(TAY_demographics, "subject_id")

```

Rename subject_id to clean_subject_id in the demographic file (to standardize the column name)

```{r}
template_df <- template_brainage %>%
  rename(clean_subject_id = participant)

```

```{r}
TAY_demographics <- TAY_demographics %>%
  rename(
    Age = age_scan,      # Rename "age_scan" to "Age"
    sex = assigned_sex_at_birth,     # Rename "assigned_sex_at_birth" to "Sex"
  )

```

```{r}
aseg_data_clean <- aseg_data_clean %>%
  rename(
    GMV = TotalGrayVol,      
    WMV = CerebralWhiteMatterVol, 
    sGMV = SubCortGrayVol,
  )

```

```{r}
brainvol_data_clean <- brainvol_data_clean %>%
  rename(
    Ventricles = VentricleChoroidVol
  )
```

Add the sex specific subject_ID, age, and assigned sex to the template_df and this also ensures that there are enough rows to merge the data. 

```{r}

# Make sure the subject_ids, sex, and age are character data types
template_df$clean_subject_id <- as.character(template_df$clean_subject_id)
template_df$sex <- as.character(template_df$sex)  # Add sex column conversion
template_df$Age <- as.character(template_df$Age)  # Add age column conversion

# First, check if template_df has rows
if (nrow(template_df) == 0) {
  # Create an empty data frame with the same structure as template_df but add the subject IDs and age
  # Keep all the original columns, but add the new data
  template_df <- template_df[0, ]  # Retain column structure but no rows
  
  # Now create a new data frame that only updates clean_subject_id and AGE
  new_data <- data.frame(clean_subject_id = template_df$clean_subject_id,
                         Age = template_df$Age,
                         sex = template_df$sex,
                         stringsAsFactors = FALSE)
  
  # Make them the same data type
  new_data$clean_subject_id <- as.character(new_data$clean_subject_id)
  new_data$sex <- as.character(new_data$sex)
  new_data$age <- as.character(new_data$Age)
  
  # Bind the new data to the empty template, ensuring columns remain intact
  template_df <- bind_rows(template_df, new_data)
} else {
  
  # If template_df already has rows, just update clean_subject_id and AGE columns
  template_df$clean_subject_id <- template_df$clean_subject_id
  template_df$Age <- template_df$Age
}
```

Add the default values for the SITE (1 because they were all taken at the same site on the same scanner), ScannerType, and FreeSurfer_Version. Change values if needed. 

```{r}

# Create a named list of default values for columns with missing data
default_values <- list(
  study = "TAY",
  country = "Canada",
  run = "1",
  session = "1",
  dx = "CN",
  ScannerType = "3",
  fs_version = "7.0"
)

# Update existing columns with default values if they are NA
for (col in names(default_values)) {
  if (col %in% names(template_df)) {
    template_df[[col]] <- ifelse(is.na(template_df[[col]]), default_values[[col]], template_df[[col]])
  }
}
```

Convert all the columns from the files that need to be merged to characters so that they can be merged.

```{r}

# Convert all columns in the template_df to characters
template_df <- template_df %>%
  mutate(across(everything(), as.character))

brainvol_data_clean <- brainvol_data_clean %>%
  mutate(across(everything(), as.character))

aseg_data_clean <- aseg_data_clean %>%
  mutate(across(everything(), as.character))

```

Populate the template df by joining the aseg, surface area, and thickness data. 

```{r}
final_template <- left_join(template_df[, c(1, 2, 3, 4, 5, 6)], aseg_data_clean, by = "clean_subject_id") %>%  
  left_join(brainvol_data_clean, by = "clean_subject_id")

# Select only the columns from template_df
final_template <- final_template %>%
  select(names(template_df))  # Keeps only the columns in template_df  

#remove columns with NA
final_template <- final_template %>%
  filter(!is.na(final_template[[7]]))

#remove participant 00000020

final_template <- final_template %>%
  filter(clean_subject_id != "00000020")

#Revert back to original column names found in the template
colnames(final_template)[1:length(original_template_column_names)] <- original_template_column_names

```

Save the final populated template into a new Excel file

```{r}

output_file <- paste0("../data/processed/", tolower(sex), "_populated_brainAGE_template.csv")
write.csv(numeric_data, output_file)

print(paste("Template has been populated and saved as", output_file))
```