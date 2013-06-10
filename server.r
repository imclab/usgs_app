require(shiny)
require(rCharts)
library(taxize)

options(xtable.type = "html")
options(xtable.include.rownames = FALSE)

shinyServer(function(input, output){

  # factor out code common to all functions.
  species2 <- reactive({
    strsplit(input$spec, ",")[[1]]
  })
  
  output$tnrs <- renderTable({
    tnrs(species2(), getpost="POST", source_ = "NCBI")[,1:5]
  })
  
  output$rank_names <- renderTable({
    tax_name(query=species2(), get=c("genus", "family", "order", "class", "kingdom"), db="ncbi")
  })
  
  bar <- reactive({
    df <- gisd_isinvasive(x=species2(), simplify=TRUE)
    df$status <- gsub("Not in GISD", "Not Invasive", df$status)
    df
  })
  
  output$invasiveness <- renderTable({
    bar()
  })
  
  output$phylogeny <- renderPlot({
    require(ape); require(ggphylo); require(doMC)    
    # Make phylogeny
    registerDoMC(cores=4)
    phylog <- phylomatic_tree(taxa=species2(), get = 'POST', informat='newick', method = "phylomatic",
                              storedtree = "R20120829", taxaformat = "slashpath", outformat = "newick", clean = "true", parallel=TRUE)
    phylog$tip.label <- capwords(phylog$tip.label)
    
    for(i in seq_along(phylog$tip.label)){
      phylog <- tree.set.tag(phylog, tree.find(phylog, phylog$tip.label[i]), 'circle', bar()[bar()$species %in% gsub("_"," ",phylog$tip.label[i]),"status"])
    }
    
    p <- ggphylo(phylog, label.size=5, label.color.by='circle', label.color.scale=scale_colour_discrete(name="", h=c(90, 10))) +
      theme_bw(base_size=18) +
      theme(panel.grid.major = element_blank(),panel.grid.minor = element_blank(),panel.background = element_blank(),
            axis.title.x = element_text(colour=NA),
            axis.title.y = element_blank(),
            axis.text.x = element_blank(),
            axis.text.y = element_blank(),
            axis.line = element_blank(),
            axis.ticks = element_blank(),
            panel.border = element_blank())
    print(p)
  })
  
  occur_data <- reactive({
    rcharts_prep1(sppchar = input$spec, occurrs = input$numocc, datasource = input$datasource)
#     rcharts_prep1(sppchar = 'Carpobrotus edulis,Rosmarinus officinalis,Ageratina riparia', occurrs = 10, datasource = "BISON")
  })
  
  rcharts_data <- reactive({
    rcharts_prep2(occur_data(), palette_name = get_palette(input$palette), popup = TRUE)
#     rcharts_prep2(bbb, palette_name = "Blues", popup = TRUE)
  })
  
  # Interactive rCharts map (thanks Ramnath)
  output$map_rcharts <- renderMap({  
    imap = gbifmap2(input = rcharts_data(), input$provider)
#     imap = gbifmap2(input = ccc, "MapQuestOpen.OSM")
    imap$legend(
      position = 'bottomright',
      colors = get_colors(species2(), get_palette(input$palette)),
      labels = species2()
    )
    imap
  })
  
  # full screen interactive chart
#   output$map_rcharts_fullscreen <- renderMap({  
#     imap = gbifmap2(input = rcharts_data(), input$provider, width=1600, height=800)
#     imap$legend(
#       position = 'bottomright',
#       colors = get_colors(species2(), get_palette(input$palette)),
#       labels = species2()
#     )
#     imap
#   })
#   
  output$papers <- renderText({
    require(rplos); require(xtable); require(plyr)
    dat <- llply(species2(), function(x) searchplos(x, fields='id,journal,title', limit = input$paperlim, key='WQcDSXml2VSWx3P')[,-4])
    names(dat) <- species2()
    dat <- ldply(dat)
    dat$id <- paste0("<a href='http://macrodocs.org/?doi=", dat$id, "' target='_blank'> <i class='icon-book'></i> </a>")
    names(dat) <- c("Species","Read","Journal","Title")
#     options(xtable.type = "html")
#     options(xtable.include.rownames = FALSE)
    g <- print(xtable(dat), type="html")
    gsub("\n", "", gsub("&gt ", ">", gsub("&lt ", "<", g)))
  })
})
