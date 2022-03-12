library("tidyverse")
library("cowplot")
library("ggforce")

df_wine <- read.csv("red_wine4_30")
wines <- df_wine[complete.cases(df_wine),] # complete cases
wines[,"y_old"] <- year(Sys.Date())-wines$wine_year # age of wine
#wines$scaled <- scale(wines$wine_rating) # scale wine rating
wines$tc <- paste(wines$type,wines$wine_country) # create wine type + country pairs (incase data has more then one type of wine)
include <- as.data.frame(table(wines$tc)) # count wine type + country pairs
include<- include[include$Freq >10,] # Vector of rows to include
wines <- wines[wines$tc %in% include$Var1,] # Filter

glimpse(wines)

wines %>% head()
wines <- wines[,c(2,4,7,8,9,10,6)] #Select all countries of interests
colnames(wines)

summary(wines)
######## wine price over some stats
wines %>% ggplot()+
  geom_point(aes(y = .panel_y, x = .panel_x, alpha = 0.05))+
  facet_matrix(rows = vars(wine_rating,n_ratings,y_old,wine_country), cols = vars(wine_price))+
  theme_cowplot()

##### Scatter plots and a few boxplots
sp1 = wines %>% ggplot(aes(x=wine_rating, y = wine_price))+
  geom_point( color = "blue", alpha=0.2)+
  geom_smooth()
sp2 = wines %>% ggplot(aes(x=n_ratings, y = wine_price))+
  geom_point( color = "blue", alpha=0.2)+
  geom_smooth()
sp3 = wines %>% filter(y_old <=20) %>%ggplot(aes(x=y_old, y = wine_price))+
  geom_point( color = "blue", alpha=0.2)+
  geom_smooth()
#sp4 = wines %>% ggplot(aes(x=wine_country, y = wine_price))+
#  geom_point( color = "blue", alpha=0.2)+
#  geom_smooth()

bp1 = wines %>% ggplot(aes(x=wine_rating, y = wine_price, group = wine_rating))+
  geom_boxplot( color = "blue", alpha=0.2)
#bp2 = wines %>% ggplot(aes(x=n_ratings, y = wine_price,group = n_ratings))+
#  geom_boxplot( color = "blue", alpha=0.2)
bp3 = wines %>% filter(y_old <=20)%>% ggplot(aes(x=y_old, y = wine_price, group = y_old))+
  geom_boxplot( color = "blue", alpha=0.2)
bp4 = wines %>% ggplot(aes(x=wine_country, y = wine_price))+
  geom_boxplot( color = "blue", alpha=0.2)

cowplot::plot_grid(sp1,sp2,sp3,bp1,bp4,bp3)
########


#write.csv(wines, file = "ProjectData.csv")

#wines %>% group_by(tc) %>%
#  summarise( sd = sd(wine_rating),mean = mean(wine_rating), freq = n()) %>%
#  mutate(t = (mean-3.7)/(sd/freq^0.5)) %>% arrange(desc(t))
### Histogram Freq
hist(x=wines$wine_rating,freq = F)

# Number of rating distribution
hist(x=wines$n_ratings, freq = F,xlim = c(0,5000),breaks = 300)
hist(x=wines[wines$n_ratings <= 500,"n_ratings"], freq = F,xlim = c(0,500),breaks = 20)
# Distribtuion of wines' ages
qplot(x = y_old, data = wines, geom="bar",xlim = c(0,20))

wines %>% group_by(wine_country) %>% summarise(n =n()) %>% 
  ggplot(aes(x = reorder(wine_country, -n), y= n))+
  geom_bar(position = 'dodge', stat='identity') +
  geom_text(aes(label=n), position=position_dodge(width=0.9), vjust=-0.25)+
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))
#summarise(wines$wine_rating)

#H0 all countries have same wine mean rating, Ha some countries make better wine
# One tailed test with a = 0.005, t>2.56

### Does any country make better wine?
wines %>% group_by(wine_country) %>% summarise( sd = sd(wine_rating),mean = mean(wine_rating), freq = n()) %>%
  mutate(t = (mean-mean(wines$wine_rating))/(sd/freq^0.5)) %>% mutate(Ha = ifelse(t>2.56,T,F)) %>% arrange(desc(t))%>%
  ggplot (aes(x = wine_country, y = t, fill = Ha)) + geom_col() +
  labs(x = "Countries", y = "t statistic", title = "Wine ratings t-test", fill = "Better?")

### Looking at wineries (not included currently)
wines %>% group_by(winery) %>% summarise(mean = mean(wine_rating), n = n())%>%filter(n>=5)%>% arrange(desc(mean))
wines %>% group_by(winery, wine_country) %>% summarise(mean = mean(wine_rating), n = n())%>%
  filter(n>=5)%>% arrange(desc(mean)) 

# whether n_ratings correlates with better wine
mean = mean(wines$wine_rating)
sd = sd(wines$wine_rating)
wines%>% ggplot(aes(x = n_ratings,y = ((wine_rating)-mean)/sd))+
  geom_point()+stat_smooth(method= "lm")

# Looking at how age, country and rating are related
wines %>% filter(y_old<=10)%>%group_by(y_old, wine_country) %>% summarise(mean = mean(wine_rating))%>%
  ggplot(aes(x = y_old,y = mean))+geom_line()+stat_smooth(method= "lm")+facet_grid(cols = vars(wine_country))

### old, might be useful
cols_var <- colnames(wines)[c(3,4,5,7,8,9)]
wines %>% ggplot() +
  geom_point(aes(x = .panel_x, y = .panel_y)) +
  facet_matrix(rows = vars(wine_rating), cols =vars(all_of(cols_var)))


# Linear Model
wines_price_lm <- wines %>% filter(y_old<=10, n_ratings >= 30)
lm_price_model <- lm(wine_price ~ y_old + wine_country + n_ratings + wine_rating,data = wines_price_lm)
summary(lm_price_model)
yhat <- predict(lm_price_model, wines_price_lm)
y <- wines_price_lm[,5]
hist((yhat-y))

#### Building logistic regression
wines_glm <- wines %>% filter(y_old<=10, n_ratings >= 30) %>% mutate(good = ifelse(wine_rating>=mean,1,0))
smp_size <- floor(0.8 * nrow(wines_glm))
set.seed(123)
train_ind <- sample(seq_len(nrow(wines_glm)), size = smp_size)
train <- wines_glm[train_ind,]
test <- wines_glm[-train_ind,]
test_good <- test$good

# General Linear Model for good or bad
lmmodel <- lm(good ~ y_old + wine_country + n_ratings + wine_price,data = train, family = "binomial")
summary(lmmodel)

predicted = predict(lmmodel, test,type = "response")

library(pROC)
ROC <- roc(test$good,predicted)
plot(ROC, col = "red")
auc(ROC)
##################################################
qplot(x = wine_country, data = wines, geom="bar") + 
  stat_bin(binwidth=1, geom='text', color='white', aes(label=..count..),
           position=position_stack(vjust = 0.5))+
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))
wines %>% group_by(wine_country) %>% summarise(n =n()) %>% ggplot(aes(x = wine_country, y= n))+
  geom_bar(position = 'dodge', stat='identity') +
  geom_text(aes(label=n), position=position_dodge(width=0.9), vjust=-0.25)+
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))


wines %>% filter(y_old<=10)%>%group_by(y_old, wine_country) %>% summarise(mean = mean(wine_rating))%>%
  ggplot(aes(x = y_old,y = mean))+geom_line()+stat_smooth(method= "lm")+facet_grid(cols = vars(wine_country))+
  theme(axis.text.x = element_text(angle = 45, vjust = 0.5, hjust=1)) + labs(title = "Rating, Age and Countries")+ ylab("Mean Rating") + xlab("Wine Age")
