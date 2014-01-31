---
title: Arbitrary Fun: Generating User Profiles with QuickCheck
date: 2014-01-31
tags: code, haskell
metadescription: How to use QuickCheck to generate random data for other programs
---

QuickCheck is a popular property-based testing library for Haskell, and I
recommend checking out the HaskellWiki's
[Introduction to QuickCheck](http://www.haskell.org/haskellwiki/Introduction_to_QuickCheck2)
if you've never used it.

But QuickCheck does more than help us write tests: it offers an efficient, rich
API for randomly generating data. We're going to show how you can generate a
CSV file with potentially millions of fake user records. The main use case is
populating a database with loads of data for interactive testing, but this
method is also useful for testing outside programs and bulk data jobs.

This post is written in literate Haskell, so let's get our obligatory top-level
imports out of the way before we get too far along:

> {-# LANGUAGE OverloadedStrings #-}
>
> import           Data.Time
> import           Data.Char (chr)
> import           Test.QuickCheck
> import           Control.Applicative
> import           Data.Vector (Vector, (!))
> import qualified Data.Vector as V
> import           Data.Text (Text)
> import qualified Data.Text as T
> import qualified Data.Text.IO as TIO
> import           System.Environment (getArgs)
> import           Text.Read (readMaybe)


<h3>Imaginary users</h3>

We'll start with a basic user profile definition, similar to what you'll find
on many social media sites:

> data UserProfile = UserProfile {
>     firstName :: Text
>   , lastName  :: Text
>   , email     :: Email
>   , password  :: Text
>   , gender    :: Gender
>   , birthday  :: Birthday
>   } deriving Show
>
> -- helper for rendering a UserProfile as text
> -- (passwords will be quoted, and generated without "" marks or control chars)
> profileText :: UserProfile -> Text
> profileText profile = T.intercalate "," [
>     firstName profile
>   , lastName  profile
>   , emailToText   $ email    profile
>   , T.concat ["\"", password profile, "\""]
>   , T.pack . show $ gender   profile
>   , T.pack . show $ birthday profile
>   ]


Note: the use of a binary gender definition here is to emulate the type of
profile I've tested against, but it's also exclusionary and a poor UI decision
([read
this](http://www.sarahdopp.com/blog/2010/designing-a-better-drop-down-menu-for-gender/)
for some alternatives and reasons not use it).

Next we'll create our custom Email, Gender, and Birthday types:

> data Email = Email {
>     local  :: Text
>   , domain :: Text
>   } deriving Show
>
> emailToText :: Email -> Text
> emailToText e = T.concat [local e, "@", domain e]
>
> data Gender = Female | Male
>   deriving Show
>
> data Birthday = Birthday {
>     year  :: Integer
>   , month :: Int
>   , day   :: Int
>   }
>
> -- display birthdays in the format YYYY-MM-DD
> instance Show Birthday where
>   show bday = show $ fromGregorian (year bday) (month bday) (day bday)


<h3>Generating data bit by bit</h3>

QuickCheck has an
[Arbitrary](http://hackage.haskell.org/package/QuickCheck-2.6/docs/Test-QuickCheck.html#g:7)
typeclass that you can use for defining how to randomly generate a piece of data
for a given type. Arbitrary instances only require you to supply a definition of
*arbitrary* (`Gen a`).

Here we'll define a Gender instance using *elements* (`[a] -> Gen a`):

> instance Arbitrary Gender where
>   arbitrary = elements [Female, Male]

Now we'd like to do the same for birthdays. Using the Data.Time library, we can
represent dates as modified Julian days. Here I've arbitrarily chosen to
generate birthdays between day 25,000 (1927-04-30) and day 55,000 (2009-06-18)
inclusive, along with a helper function for converting the integer day to a
Birthday.

> instance Arbitrary Birthday where
>   arbitrary = birthdayFromInteger <$> choose (25000, 55000)
>
> birthdayFromInteger :: Integer -> Birthday
> birthdayFromInteger i = let (y, m, d) = toGregorian (ModifiedJulianDay i) in
>   Birthday { year = y, month = m, day = d }

QuickCheck makes the choice for us using *choose* (`Random a => (a, a) -> Gen
a`), and we use *fmap* (&lt;$&gt;) to apply our helper function of `Integer ->
Birthday`.

<h3>Beyond arbitrary</h3>

Next we'd like to generate passwords, but there's a potential issue: we've
defined names and passwords to all be of type Text. How can we define
a single instance of Arbitrary Text to cover all of these cases?

There are several ways to approach this problem, and in a real application you
could make a strong argument for creating new data types (or newtypes) for each
of these fields. But in our example, the simplest answer is to not define an
instance of Arbitrary for the name and field records. The *arbitrary* function
is type `Gen a`, and we can write our own functions of this type without
Arbitrary:

> -- creates a text password of random length from the characters A-z, 0-9, and:
> --   #$%&'()*+,-./:;<=>?@[\]^_`{|}~
> genPassword :: Gen Text
> genPassword = T.pack <$> listOf1 validChars
>   where validChars = chr <$> choose (35, 126)

By design we won't generate passwords containing quotation marks or other
characters that would require escaping. This is done purely to keep this example
short and make our job easier when we eventually print results in a minimal CSV
format. If you find yourself writing a full-fledged program for generating CSV
data, I recommend using
[cassava](http://hackage.haskell.org/package/cassava-0.1.0.1/docs/Data-Csv.html).

<h3>Naming things</h3>

Any programmer will tell you that naming is hard. So let's cheat: the US
government offers lists of first and last names from [1990 census
data](https://www.census.gov/genealogy/www/data/1990surnames/names_files.html).

I've cleaned up that data so names are in Title Case, one name per line, in
files named: female_first_names, male_first_names, and last_names. There are
less than 90,000 names total in all the files so we can easily store them in
memory, and we'd like to access any element by index in constant
time. This is a job for
[Data.Vector](http://hackage.haskell.org/package/vector-0.10.9.1)!

This means we'll need a function of `Vector Text -> Gen Text` to choose
a random name from a vector of names, so let's create some helper functions:

> nameFromVector :: Vector Text -> Gen Text
> nameFromVector v = (v !) <$> choose (0, upperBound)
>   where upperBound = V.length v - 1
>
> vectorFromFile :: FilePath -> IO (Vector Text)
> vectorFromFile path = V.fromList . T.lines <$> TIO.readFile path
>
> nameGenFromFile :: FilePath -> IO (Gen Text)
> nameGenFromFile path = nameFromVector <$> vectorFromFile path

And since we'll need to pass around multiple generators, we can capture them in
a new data structure (saving us from passing around three different generators
to every function that needs them):

> data NameGenerators = NameGenerators {
>     femaleFirstNames :: Gen Text
>   , maleFirstNames   :: Gen Text
>   , lastNames        :: Gen Text
>   }

And finally, our function for loading all of the NameGenerators:

> allNameGenerators :: IO NameGenerators
> allNameGenerators = NameGenerators <$> nameGenFromFile "female_first_names"
>                                    <*> nameGenFromFile "male_first_names"
>                                    <*> nameGenFromFile "last_names"

Hardcoding filepaths isn't exactly a Best Practice<sup>TM</sup>, but in
this case if a file isn't found, we want the program to fail hard, and the
default "&lt;filepath&gt;: openFile: does not exist (No such file or directory)" error
message is sufficient.

<h3>Emails that kind of look like emails</h3>

QuickCheck is very good at generating random data, so the challenge with
generating email addresses is not what to generate, but what not to generate.
If you're clicking interactively through a test site and every email looks like
"r36oEx04C4d8l9q6q38V3xMu@Vj4WWrRcZdpCsKy904Dhz65Uy0.com" it's a little
discomfiting.

For the domain portion of the email address, we'll prepare a small list of
popular domains and a made up weighted values to decide how frequently each
should occur (we'll see how to make use of these values soon):

> emailDomains :: [(Int, Gen Text)]
> emailDomains = map (\ (i, t) -> (i, pure t)) [
>     (50, "yahoo.com")
>   , (40, "hotmail.com")
>   , (30, "aol.com")
>   , (20, "gmail.com")
>   , (10, "sbcglobal.net")
>   , (8,  "yahoo.co.uk")
>   , (6,  "yahoo.ca")
>   ]

We could automate building a list like this from a file containing many more
domains and actual frequencies if we really
wanted to match historical data or real world usage in a particular context.

Next we'd like to create a couple of functions to generate the local
part of an email address in different ways. We'll start with two plausible
forms, &lt;first initial&gt;&lt;last name&gt; and &lt;last
name&gt;&lt;digits&gt;:

> -- initialWithLast "Foo" "Bar" would produce a generator returning "fbar"
> initialWithLast :: Text -> Text -> Gen Text
> initialWithLast fName lName = pure $ initial `T.cons` rest
>   where initial = T.head . T.toLower $ fName
>         rest    = T.toLower lName
>
> -- lastWithNumber "Bar" will return barXX (XX for any two digits 11-99)
> lastWithNumber :: Text -> Gen Text
> lastWithNumber lName = T.append namePart <$> numberPart
>   where namePart   = T.toLower lName
>         numberPart = T.pack . show <$> numId
>         numId      = choose (11, 99) :: Gen Int
>

We can put it all together using QuickCheck's *oneof* (`[Gen a] -> Gen a`)
to randomly choose from the above functions for the local part, and *frequency*
(`[(Int, Gen a)] -> Gen a`) to select domains from our weighted list:

> genEmail :: Text -> Text -> Gen Email
> genEmail f l = Email <$> oneof [initialWithLast f l, lastWithNumber l]
>                      <*> frequency emailDomains

These examples are only meant to be illustrative, and while the email addresses
will look somewhat convincing, there won't be much variation. You can always
extend the list of strategies with as many email patterns as you can think of:
first name with last initial, nick names, foods, random dictionary words,
incorporating the user's birth year in any of the other patterns, etc.


<h3>The full profile</h3>

We finally have all of the generators we need to create a complete user profile:

> genUserProfile :: NameGenerators -> Gen UserProfile
> genUserProfile nameGens = do
>   gender   <- arbitrary
>   bDay     <- arbitrary
>   fName    <- case gender of
>     Female -> femaleFirstNames nameGens
>     Male   -> maleFirstNames   nameGens
>   lName    <- lastNames nameGens
>   email    <- genEmail fName lName
>   password <- genPassword `suchThat` ((>5) . T.length)
>   return $ UserProfile fName lName email password gender bDay

Note that we create a new password generator on the fly using the *suchThat*
modifier (`Gen a -> (a -> Bool) -> Gen a`) with our original generator. We
could have placed this constraint in the *genPassword* definition, but this
example shows how you can easily create modified generators for particular use
cases.


<h3>Producing data</h3>

QuickCheck is mostly designed to help you test generated data, not generate data
for arbitrary uses (hah, hah). But even though it doesn't export tools for
working with the internals of Gen directly, it does export a function called
*sample'* that always generates a list of 11 results in the IO monad. We can
pair this with *concat* and the *vectorOf* generator to create as many elements
as we want, as long as you want multiples of 11. In case you don't, we'll apply
*take* to ensure we only extract the requested number of elements:

> generate :: Int -> Gen a -> IO [a]
> generate n gen = take n . concat <$> (sample' . vectorOf count) gen
>   where count = ceiling $ fromIntegral n / 11.0

If this looks like a hack, well, sure. It is. The *sample'* function exists for
debugging purposes and isn't a perfect fit here, but it's the only exported
function we have to work with that will give us `Gen a -> IO [a]`.

<h3>Main</h3>

We can round out the program with some basic command-line arg handling (allowing
a user to specify the number of records to generate), and a main method for printing
data in our CSV-compatible but not exactly robust format.

> countDefault :: Int
> countDefault = 100
>
> -- tries to read the first command-line arg as an Int (the number of records
> -- to generate), otherwise uses the default.
> handleArgs :: [String] -> Int
> handleArgs []    = countDefault
> handleArgs (x:_) = case readMaybe x :: Maybe Int of
>   Just n  -> n
>   Nothing -> countDefault
>
> main = do
>   count      <- handleArgs     <$> getArgs
>   profileGen <- genUserProfile <$> allNameGenerators
>   profiles   <- generate count profileGen
>   TIO.putStrLn "first,last,email,password,gender,birthday"
>   mapM_ (TIO.putStrLn . profileText) profiles

<h3>A dash of cabal</h3>

Here's a snippet from the arbitraryfun cabal file if you'd like to use this as
an executable:

```text
executable arbitraryfun
  hs-source-dirs:      src
  main-is:             Main.lhs
  default-language:    Haskell2010
  build-depends:       base        >= 4.6
                     , QuickCheck  >= 2.6
                     , time        >= 1.4
                     , text        >= 1.1
                     , vector      >= 0.10
```

Keep in mind you'll also need to:

* copy and paste the text content of this post into src/Main.lhs
* create your own name lists (files named female_first_names, male_first_names,
  and last_names)
* ensure the name files are in the current working directory when you run it


<h3>Seeing it in action</h3>

And after all of our work, here's what we get on a sample run:

```console
$ arbitraryfun 10
first,last,email,password,gender,birthday
Kathey,Hodgeman,hodgeman94@hotmail.com,"%.=kn3",Female,1947-11-15
Lorri,Weyland,weyland73@yahoo.com,"v/.;}?",Female,1990-02-06
Celena,Kali,ckali@yahoo.com,"pg(VjsR",Female,1981-10-14
Blaine,Mellema,mellema21@sbcglobal.net,"l{Um:-b6k",Male,1990-07-02
Bud,Potempa,potempa27@gmail.com,"JB:*]*>",Male,1993-01-28
Aletha,Schoenecker,aschoenecker@yahoo.com,"#A%6lUf",Female,1998-10-13
Connie,Romesburg,cromesburg@yahoo.com,"$Y$>iEl>e",Male,1950-01-27
Ione,Primus,primus66@hotmail.com,"B[9^K+qnj<f9'",Female,1993-05-10
Sylvia,Magorina,smagorina@yahoo.com,"^+#p1l+",Female,2007-01-13
Fermin,Lampey,flampey@sbcglobal.net,"pq@f<v8m*",Male,1929-07-11
````

This is by no means a robust program, but we've put enough constraints on the
generated data that you should be able to view it in a spreadsheet or use it
with many CSV import tools. In a completely non-rigorous benchmark this program
was able to generate about 40,000 records in a second, and thanks to lazy
Haskell magic, QuickCheck, and Data.Text, it also showed a low, constant memory
usage even when generating 10 million records and piping them to a file (a
process that took less than 4 minutes).

