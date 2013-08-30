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
    let assets = ["images/*", "js/**", "scores/*", "css/fonts/*", "slides/**"]

    match (foldr1 (.||.) assets) $ do
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
                  , baseCtx ]

            let basePostMetaCtx = mconcat
                  [ constField "metadescription" "Chromatic Leaves post archive"
                  , baseCtx ]

            makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html" postListCtx
                >>= loadAndApplyTemplate "templates/base.html"  basePostMetaCtx
                >>= relativizeUrls

    -- post listings by tag
    tagsRules tags $ \tag pattern -> do
        let title = "Tagged: " ++ tag
        route idRoute
        compile $ do
            posts <- constField "posts" <$> postList pattern postCtx recentFirst

            let tagsMeta = "Chromatic Leaves blog posts tagged as " ++ tag

            let baseTagsMetaCtx = mconcat
                  [ constField "metadescription" tagsMeta
                  , baseCtx ]

            makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html" posts
                >>= loadAndApplyTemplate "templates/base.html"  baseTagsMetaCtx
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
          let comp = \item -> do
                primaryTag <- getMetadataField' (itemIdentifier item) "usetag"
                postList (explorePattern tags primaryTag) postCtx recentFirst

          -- create a context to use the filtered post listing
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

    -- Render an atom feed for all posts
    create ["rss.xml"] $ do
        route idRoute
        compile $ do
            loadAllSnapshots "posts/*" "content"
                >>= fmap (take 10) . recentFirst
                >>= renderAtom (feedConfiguration "All posts") feedCtx




-- -----------------------------------------------------------------------------
-- * Contexts

-- | Creates a "year" context from a string representation of the current year
yearCtx :: String -> Context String
yearCtx year = field "year" $ \item -> return year

-- | Given a collection of Tags, builds a context with a rendered tag cloud
tagCloudCtx :: Tags -> Context String
tagCloudCtx tags = field "tagcloud" $ \item -> rendered
  where rendered = renderTagCloud 85.0 165.0 tags

-- | Creates the default/base context used on all pages
makeDefaultCtx :: String -> Tags -> Context String
makeDefaultCtx year tags = mconcat
  [ defaultContext
  , yearCtx     year
  , tagCloudCtx tags
  ]

-- | Creates the default post context used by pages with posts/post listings
defaultPostCtx :: Tags -> Context String
defaultPostCtx tags = mconcat
  [ dateField "date" "%B %e, %Y"
  , tagsField "tags" tags
  , defaultContext
  ]

feedCtx :: Context String
feedCtx = mconcat
    [ bodyField "description"
    , defaultContext
    ]

-- -----------------------------------------------------------------------------
-- * Compilers

-- | Creates a compiler to render a list of posts for a given pattern, context,
-- and sorting/filtering function
postList :: Pattern
         -> Context String
         -> ([Item String] -> Compiler [Item String])
         -> Compiler String
postList pattern postCtx sortFilter = do
    posts   <- sortFilter =<< loadAll pattern
    itemTpl <- loadBody "templates/post-item.html"
    applyTemplateList itemTpl postCtx posts

-- | Compiles an asset with the sass utility
sassCompiler :: Compiler (Item String)
sassCompiler =
  getResourceString
    >>= withItemBody (unixFilter "sass" ["-s", "--scss"])
    >>= return . fmap compressCss

-- -----------------------------------------------------------------------------
-- * Atom feed

-- | Builds an atom FeedConfiguration for the site or for a specific tag
feedConfiguration :: String -> FeedConfiguration
feedConfiguration title = FeedConfiguration
    { feedTitle       = "chromatic leaves - " ++ title
    , feedDescription = "Eric Rasmussen's personal blog"
    , feedAuthorName  = "Eric Rasmussen"
    , feedAuthorEmail = "eric@chromaticleaves.com"
    , feedRoot        = "http://chromaticleaves.com"
    }

-- -----------------------------------------------------------------------------
-- * Helpers

-- | Because I never remember to update the copyright in the footer
getCurrentYear :: IO String
getCurrentYear = formatTime defaultTimeLocale "%Y" <$> getCurrentTime

-- | Builds a pattern to match only posts tagged with a given primary tag.
-- For instance, only matching posts tagged "code" on the explore/code page.
explorePattern :: Tags -> String -> Pattern
explorePattern tags primaryTag = fromList identifiers
  where identifiers = fromMaybe [] $ lookup primaryTag (tagsMap tags)
