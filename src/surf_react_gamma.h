/* ----------------------------------------------------------------------
   SPARTA - Stochastic PArallel Rarefied-gas Time-accurate Analyzer
   http://sparta.github.io
   Steve Plimpton, sjplimp@gmail.com, Michael Gallis, magalli@sandia.gov
   Sandia National Laboratories

   Copyright (2014) Sandia Corporation.  Under the terms of Contract
   DE-AC04-94AL85000 with Sandia Corporation, the U.S. Government retains
   certain rights in this software.  This software is distributed under
   the GNU General Public License.

   See the README file in the top-level SPARTA directory.
------------------------------------------------------------------------- */

#ifdef SURF_REACT_CLASS

SurfReactStyle(gamma,SurfReactGamma)

#else

#ifndef SPARTA_SURF_REACT_GAMMA_H
#define SPARTA_SURF_REACT_GAMMA_H

#include "mpi.h"
#include "surf_react.h"

namespace SPARTA_NS {

class SurfReactGamma : public SurfReact {
 public:
  SurfReactGamma(class SPARTA *, int, char **);
  ~SurfReactGamma();
  void init();
  int react(Particle::OnePart *&, int, double *, Particle::OnePart *&, int &);
  char *reactionID(int);
  double reaction_coeff(int);
  const char *gs_model();
  int match_reactant(char *, int);
  int match_product(char *, int);
  void tally_update();
  void grid_changed();

 private:
  int me,nprocs;
  int distributed;
  int mode;
  int firstflag;
  int tally_only_flag;
  int only_one_flag;

  // only_one state is stored once globally, on the unique owner of each
  // explicit surface or box face.  Collision procs access it through RMA.

  MPI_Win one_state_win;
  int *one_state_owned;
  int one_state_nown;

  double twall;
  double nsite;

  class RanKnuth *random;
  class SurfCollideDiffuse *diffuse;
  double diffuse_coeffs[2];

  struct OneReaction {
    char *id;
    char *id_reactants[2];
    char *id_product;
    int reactants[2];
    int product;
    double reaction_energy;
  };

  OneReaction *rlist;
  int maxlist;
  int **reaction_map;

  double *gamma_coeff;
  int *gamma_set;

  struct InitialCoverage {
    int species;
    double fraction;
  };

  InitialCoverage *initial;
  int ninitial,maxinitial;
  int *initial_set;

  int nspecies_surf;
  int *species_surf;
  int *species2surf;

  // mode = FACE for box faces

  int nface;
  double **face_species_state;
  double *face_total_state;
  double *face_area;
  double *face_weight;
  int **face_species_delta;
  int **face_sum_delta;

  // mode = SURF for explicit surface elements

  int total_state_index;
  int species_state_index;
  int area_index;
  int weight_index;

  char *total_state_name;
  char *species_state_name;
  char *area_name;
  char *weight_name;

  int **surf_species_delta;
  int *mark;
  surfint *tally2surf;
  double **incollate;
  double **outcollate;
  int maxtally;

  // pointers to either face or local+ghost surf data

  double **species_state;
  double *total_state;
  double *area;
  double *weight;
  int **species_delta;

  void readfile(char *);
  int readone(char *, char *, int &, int &);
  int read_effective_line(char *, int &);
  void print_reaction(char *, char *);

  void build_surface_species();
  void build_reaction_map();
  void create_per_face_state();
  void create_per_surf_state();
  void initialize_per_surf_state();
  void initialize_cover_face();
  void initialize_cover_surf();
  void update_state_face();
  void update_state_surf();
  void create_one_state_window();
  void one_state_location(int, int &, MPI_Aint &);
  int lock_one_state(int, int &, MPI_Aint &);
  void put_one_state(int, MPI_Aint, int);
  void sync_one_state();

  int assigned_to_this(int);
  long int max_sites(int);
  int effective_count(int, int);
  int select_surface_species(int);
  void mark_surface(int);
  char *custom_name(const char *);
};

}

#endif
#endif

/* ERROR/WARNING messages:

E: Illegal surf_react gamma command

Self-explanatory.  Check the input script syntax and compare to the
documentation for the command.

*/
