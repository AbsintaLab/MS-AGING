# AIM ---------------------------------------------------------------------
# this is the initial step for the counting of senescent cells. In this step I generate the signatures score.

# libraries ---------------------------------------------------------------
library(tidyverse)
library(ggrepel)
library(lemon)

# read in the data --------------------------------------------------------
folder <-  "../../out/table/revision/modules_AUTOPHAGY/"
# focus on the autophagy only sigantures
pattern_sig <- paste0(names(readRDS("../../data/signatures/autophagy_pathways.rds")),collapse = "|")

file <- dir(folder) %>% 
  str_subset(pattern = "Module") %>%
  str_subset(pattern = pattern_sig)

# they already have the expert annotation
df_modules <- lapply(file, function(x){
  read_tsv(paste0(folder,x))
}) %>% 
  bind_rows() %>% 
  mutate(disease = factor(disease,levels = c("CTRL","MS")))

# wrangling ---------------------------------------------------------------
# use wm ctrl as reference
id_signature <- unique(df_modules$signature)
# x <- "senmayo"
list_enumeration <- lapply(id_signature,function(x){
  # try to reference to top10% based on the control dataset
  df_90 <- df_modules %>% 
    filter(signature %in% x,
           disease %in% "CTRL",
           origin == "cortex") %>% 
    group_by(signature,expertAnno.l1) %>% 
    summarise(thr = quantile(signature_score1,prob=0.90))
  
  # enumerate the cells 090 from the control only samples
  df_en_090_1 <- df_modules %>% 
    select(barcode,signature,disease,expertAnno.l1,signature_score1,origin) %>% 
    filter(signature %in% x) %>% 
    left_join(df_90,by = c("expertAnno.l1","signature")) %>% 
    mutate(pass_thr = signature_score1>thr) %>% 
    group_by(signature,expertAnno.l1,disease,origin) %>% 
    summarise(tot_cell = n(),
              tot_sen = sum(pass_thr)) %>%
    ungroup() %>% 
    mutate(prop_sen = tot_sen/tot_cell)
  
  # count the pro of the contols
  df_en_090_2 <- df_en_090_1 %>% 
    filter(disease %in% "CTRL",
           origin == "cortex") %>% 
    select(signature,expertAnno.l1,prop_sen_ctrl=prop_sen)
  
  df_en_090_final <- df_en_090_1 %>% 
    left_join(df_en_090_2,by = c("expertAnno.l1","signature")) %>% 
    mutate(FC = prop_sen/prop_sen_ctrl,
           log2FC = log2(FC))
  
  return(df_en_090_final)
}) %>% 
  setNames(id_signature)

df_en_090_final <- bind_rows(list_enumeration)
# save the table
df_en_090_final %>% 
  write_tsv("../../out/table/revision/modules_AUTOPHAGY/121_enumeration_ALL_090_threshold_MSStatus_refCX_cellID_autophagy.tsv")

# plot all the the enumeration
df_en_090_final %>% 
  filter(tot_sen>5) %>% 
  mutate(origin2 = paste0(disease,"_",origin)) %>% 
  ggplot(aes(y=origin2,x=log2FC))+
  geom_col(aes(fill=tot_sen))+
  # geom_col(aes(width = tot_sen))+
  facet_grid(signature~expertAnno.l1)+
  theme_bw()+
  theme(strip.background = element_blank(), 
        panel.border = element_rect(colour = "black", fill = NA),
        strip.text.y.right = element_text(angle = 0))+
  scale_fill_gradientn(colours = viridis::turbo(10),trans = "log",breaks = 4^seq(1,5))+geom_vline(xintercept = 0,linetype="dashed",col="gray")
ggsave(paste0("../../out/image/revision/modules_AUTOPHAGY/121_enumeration_log2Prop_ALL_090_threshold_above5_MSStatus_CXref_cellID_autophagy.pdf"),width = 25,height =15)

# plot a smaller version of the image
# df_en_090_final %>%
#   filter(signature %in% c("CLASSICAL_SASP","Induces","Inhibits","SAEPHIA_CURATED_SASP","senmayo")) %>%
#   filter(tot_sen>5) %>%
#   mutate(origin2 = paste0(disease,"_",origin)) %>%
#   ggplot(aes(y=origin2,x=log2FC))+
#   geom_col(aes(fill=tot_sen))+
#   # geom_col(aes(width = tot_sen))+
#   facet_grid(signature~expertAnno.l1)+
#   theme_bw()+
#   theme(strip.background = element_blank(),
#         panel.border = element_rect(colour = "black", fill = NA),
#         strip.text.y.right = element_text(angle = 0))+
#   scale_fill_gradientn(colours = viridis::turbo(10),trans = "log",breaks = 4^seq(1,5))+geom_vline(xintercept = 0,linetype="dashed",col="gray")
# ggsave(paste0("../../out/image/ManualClean/modules_AUTOPHAGY/HVG4000_expertAnno/enumeration_log2Prop_ALL_090_threshold_above5_MSStatus_CXref_cellID_small.pdf"),width = 18,height =10)

# # reproduce the plot but rename and drop some signature
# df_en_090_final %>%
#   filter(signature %in% c("Induces","Inhibits","SAEPHIA_CURATED_SASP","senmayo")) %>%
#   mutate(signature2 = case_when(signature == "Induces"~"CellAge Induces",
#                                 signature == "Inhibits"~"CellAge Inhibits",
#                                 signature == "SAEPHIA_CURATED_SASP"~"Curated SASP",
#                                 signature == "senmayo"~"Senmayo")) %>%
#   filter(tot_sen>5) %>%
#   mutate(origin2 = paste0(disease,"_",origin)) %>%
#   ggplot(aes(y=origin2,x=log2FC))+
#   geom_col(aes(fill=tot_sen))+
#   # geom_col(aes(width = tot_sen))+
#   facet_grid(signature2~expertAnno.l1)+
#   theme_bw()+
#   theme(strip.background = element_blank(),
#         panel.border = element_rect(colour = "black", fill = NA),
#         strip.text.y.right = element_text(angle = 0))+
#   scale_fill_gradientn(colours = viridis::turbo(10),trans = "log",breaks = 4^seq(1,5))+geom_vline(xintercept = 0,linetype="dashed",col="gray")
# ggsave(paste0("../../out/image/revision/modules_AUTOPHAGY/121_enumeration_log2Prop_ALL_090_threshold_above5_MSStatus_CXref_cellID_small2.pdf"),width = 18,height =8)

# -------------------------------------------------------------------------
# run the proportion by cell by sample
# use the cx as reference
folder <-  "../../out/table/revision/modules_AUTOPHAGY/"
# focus on the autophagy only sigantures
pattern_sig <- paste0(names(readRDS("../../data/signatures/autophagy_pathways.rds")),collapse = "|")

file <- dir(folder) %>% 
  str_subset(pattern = "Module") %>%
  str_subset(pattern = pattern_sig)

df_modules_cellID <- lapply(file, function(x){
  read_tsv(paste0(folder,x))
}) %>% 
  bind_rows() %>% 
  mutate(disease = factor(disease,levels = c("CTRL","MS")))

LUT_sample <- read_tsv("../../out/table/revision/120_meta.data_AnnotationSCType_manualAnnotation.tsv") %>% 
  group_by(orig.ident,pathology_class) %>% 
  summarise()

# use wm ctrl as reference
id_signature <- unique(df_modules_cellID$signature)

# x <- "senmayo"
list_enumeration_cellID <- lapply(id_signature,function(x){
  df_90_cellID2 <- df_modules_cellID %>% 
    filter(signature %in% x,
           disease %in% "CTRL",
           origin == "cortex") %>% 
    group_by(signature,expertAnno.l1) %>% 
    summarise(thr = quantile(signature_score1,prob=0.90))
  
  test_summary_cellID <- df_modules_cellID %>% 
    filter(signature %in% x) %>% 
    left_join(df_90_cellID2,c("expertAnno.l1","signature")) %>% 
    mutate(sen = case_when(signature_score1>thr~1,
                           T~0)) %>% 
    group_by(signature,orig.ident,origin,disease,expertAnno.l1,sen) %>% 
    summarise(n = n()) %>% 
    ungroup() %>% 
    group_by(signature,orig.ident,origin,disease,expertAnno.l1) %>% 
    mutate(tot = sum(n)) %>% 
    ungroup() %>% 
    mutate(prop = n/tot)
  
  # add the sample id
  df_plot <- test_summary_cellID %>% 
    left_join(LUT_sample,"orig.ident") %>% 
    mutate(pathology_class = factor(pathology_class,levels = c("CX_Ctrl","CX_Demye","CX_Mye","WM_Ctrl","WM_NAWM","WM_CI","WM_CA","WM_Core")))
  
  return(df_plot)
  
}) %>% 
  setNames(id_signature)

enumeration_cellID <- bind_rows(list_enumeration_cellID)

# save the table
enumeration_cellID %>% 
  write_tsv("../../out/table/revision/modules_AUTOPHAGY/121_enumeration_ALL_090_threshold_MSStatus_refCX_cellID_sampleWise_autophagy.tsv")

# test_summary_cellID %>% 
#   # filter(expertAnno.l1 %in% c(3,5,11)) %>%
#   filter(sen == 1) %>% 
#   ggplot(aes(x=origin,y=prop,col=origin,label=orig.ident)) +
#   geom_boxplot(outlier.shape = NA)+
#   geom_point(position = position_jitter(width = 0.1)) +
#   geom_text_repel()+
#   facet_grid(expertAnno.l1~disease)+theme_bw()+theme(strip.background = element_blank())+geom_hline(yintercept = 0.1,linetype="dotted",col="black")

# enumeration_cellID %>%
#   # filter(expertAnno.l1 %in% c(3,5,11)) %>%
#   filter(sen == 1) %>% 
#   # ggplot(aes(x=pathology_class,y=prop,col=origin,label=orig.ident)) +
#   ggplot(aes(x=pathology_class,y=prop,col=origin)) +
#   geom_boxplot(outlier.shape = NA)+
#   geom_point(position = position_jitter(width = 0.1)) +
#   # geom_text_repel()+
#   facet_grid(signature~expertAnno.l1,scales = "free")+
#   theme_bw()+
#   theme(strip.background = element_blank(),
#         strip.text.y.right = element_text(angle = 0))+
#   geom_hline(yintercept = 0.1,linetype="dotted",col="black")+theme(axis.text.x = element_text(hjust = 1,angle = 90))
# 
# ggsave(paste0("../../out/image/revision/modules_AUTOPHAGY/121_enumeration_log2Prop_ALL_090_threshold_above5_MSStatus_CXref_cellID_sampleWise_senescence.pdf"),width = 25,height =15)

# enumeration_cellID %>%
#   # filter(expertAnno.l1 %in% c(3,5,11)) %>%
#   filter(sen == 1) %>% 
#   filter(signature %in% c("CLASSICAL_SASP","Induces","Inhibits","SAEPHIA_CURATED_SASP","senmayo")) %>% 
#   # ggplot(aes(x=pathology_class,y=prop,col=origin,label=orig.ident)) +
#   ggplot(aes(x=pathology_class,y=prop,col=origin)) +
#   geom_boxplot(outlier.shape = NA)+
#   geom_point(position = position_jitter(width = 0.1)) +
#   # geom_text_repel()+
#   facet_grid(signature~expertAnno.l1,scales = "free")+
#   theme_bw()+
#   theme(strip.background = element_blank(),
#         strip.text.y.right = element_text(angle = 0))+
#   geom_hline(yintercept = 0.1,linetype="dotted",col="black")+theme(axis.text.x = element_text(hjust = 1,angle = 90))
# 
# ggsave(paste0("../../out/image/ManualClean/modules_AUTOPHAGY/HVG4000_expertAnno/enumeration_log2Prop_ALL_090_threshold_above5_MSStatus_CXref_cellID_sampleWise_small.pdf"),width = 18,height =10)

enumeration_cellID %>%
  # filter(expertAnno.l1 %in% c(3,5,11)) %>%
  filter(sen == 1) %>% 
  # ggplot(aes(x=pathology_class,y=prop,col=origin,label=orig.ident)) +
  ggplot(aes(x=pathology_class,y=prop,col=origin)) +
  geom_boxplot(outlier.shape = NA)+
  geom_point(position = position_jitter(width = 0.1)) +
  # geom_text_repel()+
  facet_grid(signature~expertAnno.l1,scales = "free")+
  theme_bw()+
  theme(strip.background = element_blank(),
        strip.text.y.right = element_text(angle = 0))+
  geom_hline(yintercept = 0.1,linetype="dotted",col="black")+theme(axis.text.x = element_text(hjust = 1,angle = 90))

ggsave(paste0("../../out/image/revision/modules_AUTOPHAGY/121_enumeration_log2Prop_ALL_090_threshold_above5_MSStatus_CXref_cellID_sampleWise_autophagy.pdf"),width = 25,height =15)

enumeration_cellID %>%
  # filter(expertAnno.l1 %in% c(3,5,11)) %>%
  filter(sen == 1) %>%
  # filter(signature %in% c("CLASSICAL_SASP","Induces","Inhibits","SAEPHIA_CURATED_SASP","senmayo")) %>%
  # ggplot(aes(x=pathology_class,y=prop,col=origin,label=orig.ident)) +
  ggplot(aes(x=pathology_class,y=prop,col=origin)) +
  geom_boxplot(outlier.shape = NA)+
  geom_point(position = position_jitter(width = 0.1)) +
  # geom_text_repel()+
  facet_wrap(signature~expertAnno.l1,scales = "free",ncol = 9)+
  theme_bw()+
  theme(strip.background = element_blank(),
        strip.text.y.right = element_text(angle = 0))+
  geom_hline(yintercept = 0.1,linetype="dotted",col="black")+theme(axis.text.x = element_text(hjust = 1,angle = 90))
ggsave(paste0("../../out/image/revision/modules_AUTOPHAGY/121_enumeration_log2Prop_ALL_090_threshold_above5_MSStatus_CXref_cellID_sampleWise_small2_autophagy.pdf"),width = 25,height =20)
