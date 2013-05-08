--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import Hakyll
import Hakyll.Web.Tags
import Control.Applicative
import Hakyll.Core.Identifier
import Data.Maybe (fromMaybe)
import Data.Monoid (mappend, mconcat)
import Data.Time.Format (formatTime)
import Data.Time.Clock (getCurrentTime)
import System.Locale (defaultTimeLocale)

--------------------------------------------------------------------------------
main :: IO ()
main = do
  -- get the current year from the system time before entering the Rules monad
  year <- getCurrentYear

  hakyll $ do

    -- compile templates
    match "templates/*" $ compile templateCompiler

    -- copy static assets
    match ("images/*" .||. "js/**" .||. "scores/*" .||. "css/fonts/*") $ do
        route   idRoute
        compile copyFileCompiler

    -- compile scss assets
    match ("css/*" .||. "css/icons/*" .||. "foundation/*") $ do
        route $ setExtension "css"
        compile sassCompiler

    -- build tags
    tags <- buildTags "posts/*" (fromCapture "tags/*.html")

    -- base.html needs a year, tag cloud, and the defaults (title/body)
    let baseCtx   = makeDefaultCtx year tags
    let applyBase = loadAndApplyTemplate "templates/base.html" baseCtx

    -- create a specialized post context to handle individual post tags
    let postCtx    = defaultPostCtx tags

    -- our only root level static page
    match ("about.markdown" .||. "commands.markdown") $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= applyBase
            >>= relativizeUrls

    -- render each of the individual posts
    match "posts/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/post.html" postCtx
            >>= applyBase
            >>= relativizeUrls

    -- create a listing of all posts, most recent first
    create ["posts.html"] $ do
        route idRoute
        compile $ do
            let postListCtx = mconcat
                  [ field "posts" (\_ -> postList "posts/*" postCtx recentFirst)
                  , constField "title" "Posts"
                  , baseCtx ]

            makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html" postListCtx
                >>= applyBase
                >>= relativizeUrls

    -- post listings by tag
    tagsRules tags $ \tag pattern -> do
        let title = "Tagged: " ++ tag
        route idRoute
        compile $ do
            posts <- constField "posts" <$> postList pattern postCtx recentFirst
            makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html" posts
                >>= applyBase
                >>= relativizeUrls

        -- rss feeds by tag
        version "rss" $ do
            route $ setExtension "xml"
            compile $ loadAllSnapshots pattern "content"
                >>= fmap (take 10) . recentFirst
                >>= renderAtom (feedConfiguration title) feedCtx

    -- section pages
    match "explore/*" $ do
      route $ setExtension "html"

      compile $ do
        -- create a per-item compiler that will grab a list of posts by tag
          let comp = \item -> exploreCompiler item tags postCtx recentFirst
          let exploreCtx = mconcat [ field "posts" comp, baseCtx ]

          pandocCompiler
            >>= loadAndApplyTemplate "templates/explore.html" exploreCtx
            >>= applyBase
            >>= relativizeUrls


    -- our glorious home page
    match "index.html" $ do
        route idRoute
        compile $ do
            let indexCtx = field "posts" $ \_ ->
                  postList "posts/*" postCtx $ fmap (take 10) . recentFirst

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= applyBase
                >>= relativizeUrls

    -- our (maybe not so) friendly 404 page
    match "404.html" $ do
        route idRoute
        compile $ pandocCompiler >>= applyBase

    -- Render RSS feed
    create ["rss.xml"] $ do
        route idRoute
        compile $ do
            loadAllSnapshots "posts/*" "content"
                >>= fmap (take 10) . recentFirst
                >>= renderAtom (feedConfiguration "All posts") feedCtx




--------------------------------------------------------------------------------
getCurrentYear :: IO String
getCurrentYear = formatTime defaultTimeLocale "%Y" <$> getCurrentTime

yearCtx :: String -> Context String
yearCtx year = field "year" $ \item -> return year

--------------------------------------------------------------------------------
tagCloudCtx :: Tags -> Context String
tagCloudCtx tags = field "tagcloud" $ \item -> rendered
  where rendered = renderTagCloud 85.0 165.0 tags

--------------------------------------------------------------------------------
makeDefaultCtx :: String -> Tags -> Context String
makeDefaultCtx year tags = mconcat
  [ defaultContext
  , yearCtx     year
  , tagCloudCtx tags
  ]

--------------------------------------------------------------------------------
defaultPostCtx :: Tags -> Context String
defaultPostCtx tags = mconcat
  [ dateField "date" "%B %e, %Y"
  , tagsField "tags" tags
  , defaultContext
  ]

--------------------------------------------------------------------------------
postList :: Pattern
         -> Context String
         -> ([Item String] -> Compiler [Item String])
         -> Compiler String
postList pattern postCtx sortFilter = do
    posts   <- sortFilter =<< loadAll pattern
    itemTpl <- loadBody "templates/post-item.html"
    applyTemplateList itemTpl postCtx posts

--------------------------------------------------------------------------------
sassCompiler :: Compiler (Item String)
sassCompiler =
  getResourceString
    >>= withItemBody (unixFilter "sass" ["-s", "--scss"])
    >>= return . fmap compressCss

--------------------------------------------------------------------------------
feedConfiguration :: String -> FeedConfiguration
feedConfiguration title = FeedConfiguration
    { feedTitle       = "chromatic leaves - " ++ title
    , feedDescription = "Eric Rasmussen's personal blog"
    , feedAuthorName  = "Eric Rasmussen"
    , feedAuthorEmail = "eric@chromaticleaves.com"
    , feedRoot        = "http://chromaticleaves.com"
    }

--------------------------------------------------------------------------------
feedCtx :: Context String
feedCtx = mconcat
    [ bodyField "description"
    , defaultContext
    ]

--------------------------------------------------------------------------------
-- hacky but necessary until I can refactor to use snapshots
explorePattern :: Tags -> String -> Pattern
explorePattern tags usetag = fromList identifiers
  where identifiers = fromMaybe [] $ lookup usetag (tagsMap tags)

-- need to refactor so this can share code with postList
exploreCompiler :: Item a
                -> Tags
                -> Context String
                -> ([Item String] -> Compiler [Item String])
                -> Compiler String
exploreCompiler item tags postCtx sortFilter = do
  let identifier = itemIdentifier item
  usetag <- getMetadataField' identifier "usetag"
  let pattern = explorePattern tags usetag
  posts   <- sortFilter =<< loadAll pattern
  itemTpl <- loadBody "templates/post-item.html"
  applyTemplateList itemTpl postCtx posts

