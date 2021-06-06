# Introduction

- Data flow/reactive programming with RxJS
- Input and output known
- No idea what's happening in between -> Relate with [@Tanimoto_2015]
- We verified this is a real problem
- We verified that devs sprinkle print statements -> Relate with[@Tanimoto_2015]
	- This holds for novice and professional software engineers
- We have a solution: Visual Studio Code Extension for RxJS-based Applications

The basic mental model of a computer program describes a black box producing output based on the input provided it. A set of requirements describe the form of input, output and the transformation from one to the other. [@CITE SOME SOURCE ABOUT PROGRAM MENTAL MODEL]. Such a mental model proves to be inaccurate once we observe program output diverging from the constraints specified in the requirements: A calculated value is negative instead of positive or a preemptive program exit caused by an unexpected error is often the beginning of a debugging session: The software engineer attempts to align their mental model of the program with its actual runtime behavior. They repeatedly iterate through three steps: (i) Gather context to formulate and refine a hypothesis on the underlying problem, (ii) instrument the program in order to prove their hypothesis, and (iii) test the augmented program to see if the hypothesis is correct. [@CITE DEBUGGING PROCESS]

Before the raise of specific debugger utilities, software engineers had a limited set of tools available to reconstruct and analyze a programs execution behavior. Beside memory dumps and alike, print statements are known to engineers up until today: Manually added, the provide concise insight on (i) the runtime control flow of a program ("Transparency of Semantics" [@Tanimoto_2015]) as well as the (ii) internal program state ("Transparency of Data" [@Tanimoto_2015]) during its execution. This invasive method is time consuming [@CITE!] and requires clean up afterwards [@Alabor_Stolze_2020]. Modern debuggers for imperative programming environments make print statements obsolete: Step controls and stack frame inspection/manipulation allow software engineers to interact with program source code at runtime without actually modifying it; at least not for the sole reason of debugging.








# Related Work

- Types of debuggers (imperative, reactive [@Salvaneschi_Mezini_2016], omniscient [@Pothier_Tanter_2009] [@OCallahan_Jones_Froyd_Huey_Noll_Partush_2017])
- Affordances in live programming environments [@Tanimoto_2013]
- Scala Worksheets, Swift Playground, Wallaby.js
- Reactive Inspector [@Salvaneschi_Mezini_2016] for REScala (Visualization! <3)
- *Optional: RxFiddle [@Banken_Meijer_Gousios_2018]*
- *Optional: rxjs-playground https://github.com/hediet/rxjs-playground*

# Research

- Previous Work [@Alabor_Stolze_2020]
  - Interviews
  - Observational Study
- New work:
	- Prototype
	- UX Testing of Prototype [@Alabor_2020]
	- The Result: An extension for Visual Studio Code, as described in the next section:

# Implementation

- Demonstrate/describe Extension
  - Log Points -> Relate with probes/traces [@McDirmid_2013]
- Categorize Extension in terms of "Levels of Live" [@Tanimoto_2013]
- *Idea: Can we demonstrate somehow an example with hot code reloading, so we have a better "live" experience?*

# Future Work

- Features:
	- Support for Browser-based Applications (Selling point: Angular)
	- Visualization of data flows
	- Omniscient/time travel debugging for data flows
- Research:
	- Verify if extension helps beginners to get started with RxJS
	- Verify effectiveness of extension for professionals (re-execute previous observational study)
  - More Usability Testing

# Conclusion

- Wrap things up

